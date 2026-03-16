import StoreKit
import SwiftData
import SwiftUI

// MARK: - Settings

struct SettingsView: View {
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showSignOutConfirmation = false
    @State private var isSigningOut = false
    @State private var feedbackMessage: String?
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.systemDefault.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .systemDefault
    }

    var body: some View {
        List {
            if !authManager.isAnonymous {
                Section("settings.section.account") {
                    NavigationLink {
                        AccountSettingsView()
                    } label: {
                        Label("settings.account", systemImage: "person.crop.circle")
                    }
                }
            }

            Section("settings.section.billing") {
                LabeledContent {
                    Text("\(subscriptionManager.creditsRemaining) / \(subscriptionManager.monthlyLimit)")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("settings.billing.credits", systemImage: "sparkles")
                }

                LabeledContent {
                    Text(
                        subscriptionManager.isPremium
                            ? String(localized: "settings.billing.plan.premium")
                            : String(localized: "settings.billing.plan.free")
                    )
                    .foregroundStyle(.secondary)
                } label: {
                    Label("settings.billing.plan", systemImage: "crown")
                }

                LabeledContent {
                    Text(
                        subscriptionManager.nextResetAt?.formatted(
                            .dateTime
                                .year(.defaultDigits)
                                .month(.defaultDigits)
                                .day(.defaultDigits)
                                .locale(appLanguage.locale)
                        ) ?? "--"
                    )
                        .foregroundStyle(.secondary)
                } label: {
                    Label("settings.billing.resetAt", systemImage: "clock.arrow.circlepath")
                }

                if !subscriptionManager.isPremium {
                    Button {
                        Task { await purchasePremium() }
                    } label: {
                        actionRow(
                            title: "settings.billing.action.upgrade",
                            systemImage: "arrow.up.circle",
                            isLoading: subscriptionManager.isPurchasing
                        )
                    }
                    .disabled(subscriptionManager.isPurchasing || !subscriptionManager.isRevenueCatAvailable)

                    LabeledContent {
                        Text(subscriptionManager.monthlyPriceText)
                            .foregroundStyle(.secondary)
                    } label: {
                        Label("settings.billing.price", systemImage: "dollarsign.circle")
                    }
                }

                Button {
                    Task { await restorePurchases() }
                } label: {
                    actionRow(
                        title: "settings.billing.action.restore",
                        systemImage: "arrow.clockwise.circle",
                        isLoading: subscriptionManager.isRestoring
                    )
                }
                .disabled(subscriptionManager.isRestoring || !subscriptionManager.isRevenueCatAvailable)

                if !subscriptionManager.isRevenueCatAvailable {
                    Text("settings.billing.revenuecat.missingKey")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                if let billingError = subscriptionManager.lastErrorMessage, !billingError.isEmpty {
                    Text(billingError)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section("settings.section.language") {
                Picker(selection: $appLanguageRawValue) {
                    Text("settings.language.english")
                        .tag(AppLanguage.english.rawValue)
                    Text("settings.language.simplifiedChinese")
                        .tag(AppLanguage.simplifiedChinese.rawValue)
                } label: {
                    Label("settings.language", systemImage: "globe")
                }
                .pickerStyle(.menu)
            }

            Section("settings.section.support") {
                Link(destination: AppLinks.contactEmail) {
                    Label("settings.link.contactSupport", systemImage: "envelope")
                }

                Button {
                    requestReview()
                } label: {
                    Label("settings.rateApp", systemImage: "star")
                }
            }

            Section("settings.section.legal") {
                Link(destination: AppLinks.terms) {
                    Label("settings.link.terms", systemImage: "doc.text")
                }

                Link(destination: AppLinks.privacy) {
                    Label("settings.link.privacy", systemImage: "hand.raised")
                }
            }

            Section("settings.section.about") {
                LabeledContent {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                } label: {
                    Label("settings.version", systemImage: "app.badge")
                }
            }

            if !authManager.isAnonymous {
                Section {
                    Button(role: .destructive) {
                        showSignOutConfirmation = true
                    } label: {
                        actionRow(
                            title: "settings.action.signOut",
                            systemImage: "rectangle.portrait.and.arrow.right",
                            isLoading: isSigningOut
                        )
                    }
                    .disabled(isSigningOut)
                }
            }

            if authManager.isAnonymous {
                AppleSignInSettingsRow { error in
                    feedbackMessage = error
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("settings.signOut.confirm.title", isPresented: $showSignOutConfirmation) {
            Button("settings.action.signOut", role: .destructive) {
                Task { await signOut() }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.signOut.confirm.message")
        }
        .alert("settings.error.title", isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
        .task {
            await subscriptionManager.refreshBillingState()
        }
    }

    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }

        do {
            try await AuthManager.shared.signOut()
            dismiss()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }

    private func purchasePremium() async {
        do {
            try await subscriptionManager.purchasePremium()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionManager.restorePurchases()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var feedbackMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    showDeleteConfirmation = true
                } label: {
                    actionRow(
                        title: "settings.action.deleteAccount",
                        systemImage: "trash",
                        isLoading: isDeleting
                    )
                }
                .disabled(isDeleting)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.account")
        .navigationBarTitleDisplayMode(.inline)
        .alert("settings.delete.confirm.title", isPresented: $showDeleteConfirmation) {
            Button("settings.action.deleteAccount", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("settings.delete.confirm.message")
        }
        .alert("settings.error.title", isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await AuthManager.shared.deleteAccount()
            try modelContext.delete(model: Glimmer.self)
            try modelContext.delete(model: Echo.self)
            dismiss()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared Components

private func actionRow(title: LocalizedStringKey, systemImage: String, isLoading: Bool) -> some View {
    HStack(spacing: 12) {
        Label(title, systemImage: systemImage)
        Spacer()
        if isLoading {
            ProgressView()
                .controlSize(.small)
        }
    }
}

import StoreKit
import SwiftData
import SwiftUI

// MARK: - Settings

struct SettingsView: View {
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showSignOutConfirmation = false
    @State private var isSigningOut = false
    @State private var showPaywall = false
    @State private var feedbackMessage: String?
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.systemDefault.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .systemDefault
    }

    var body: some View {
        List {
            // MARK: Account Section
            Section {
                if authManager.isAnonymous {
                    AppleSignInSettingsRow { error in
                        feedbackMessage = error
                    }
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                } else {
                    NavigationLink {
                        AccountSettingsView()
                    } label: {
                        HStack(spacing: 16) {
                            Image(systemName: "person.crop.circle")
                                .font(.system(size: 36))
                                .foregroundStyle(.secondary)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(authManager.userName ?? String(localized: "settings.account.defaultName", defaultValue: "灵魂旅人"))
                                    .font(.headline)
                                if let email = authManager.userEmail {
                                    Text(email)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // MARK: Billing Section
            Section {
                LabeledContent {
                    Text("\(subscriptionManager.creditsRemaining) / \(subscriptionManager.monthlyLimit)")
                        .foregroundStyle(.primary)
                        .font(.system(.body, design: .rounded).monospacedDigit())
                } label: {
                    Label("settings.billing.credits", systemImage: "sparkles")
                }

                LabeledContent {
                    Text(
                        subscriptionManager.isPremium
                            ? String(localized: "settings.billing.plan.premium")
                            : String(localized: "settings.billing.plan.free")
                    )
                    .foregroundStyle(subscriptionManager.isPremium ? .primary : .secondary)
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
                    .font(.system(.body, design: .rounded).monospacedDigit())
                } label: {
                    Label("settings.billing.resetAt", systemImage: "clock.arrow.circlepath")
                }

                if !subscriptionManager.isPremium {
                    Button {
                        showPaywall = true
                    } label: {
                        actionRow(
                            title: "settings.billing.action.upgrade",
                            systemImage: "arrow.up.circle.fill",
                            isLoading: false,
                            isProminent: true
                        )
                    }

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
                        .foregroundStyle(.primary)
                }
            } header: {
                Text("settings.section.billing").textCase(nil)
            }

            // MARK: Preferences Section
            Section {
                Picker(selection: $appLanguageRawValue) {
                    Text("settings.language.english")
                        .tag(AppLanguage.english.rawValue)
                    Text("settings.language.simplifiedChinese")
                        .tag(AppLanguage.simplifiedChinese.rawValue)
                } label: {
                    Label("settings.language", systemImage: "globe")
                }
                .pickerStyle(.menu)
            } header: {
                Text("settings.section.language").textCase(nil)
            }

            // MARK: Support & Legal Section
            Section {
                Link(destination: AppLinks.contactEmail) {
                    Label("settings.link.contactSupport", systemImage: "envelope")
                }
                .foregroundStyle(.primary)

                Button {
                    requestReview()
                } label: {
                    Label("settings.rateApp", systemImage: "star")
                        .foregroundStyle(.primary)
                }
                
                Link(destination: AppLinks.terms) {
                    Label("settings.link.terms", systemImage: "doc.text")
                }
                .foregroundStyle(.primary)

                Link(destination: AppLinks.privacy) {
                    Label("settings.link.privacy", systemImage: "hand.raised")
                }
                .foregroundStyle(.primary)
            } header: {
                Text("settings.section.support").textCase(nil)
            }

            // MARK: About Section
            Section {
                LabeledContent {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                        .font(.system(.body, design: .rounded).monospacedDigit())
                } label: {
                    Label("settings.version", systemImage: "info.circle")
                }
            }

            // MARK: Sign Out Section
            if !authManager.isAnonymous {
                Section {
                    Button {
                        showSignOutConfirmation = true
                    } label: {
                        actionRow(
                            title: "settings.action.signOut",
                            systemImage: "rectangle.portrait.and.arrow.right",
                            isLoading: isSigningOut
                        )
                        .foregroundStyle(.primary)
                    }
                    .disabled(isSigningOut)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.title")
        .navigationBarTitleDisplayMode(.inline)
        .alert("settings.signOut.confirm.title", isPresented: $showSignOutConfirmation) {
            Button("settings.action.signOut") {
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
        .sheet(isPresented: $showPaywall) {
            PaywallView()
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

    private func restorePurchases() async {
        do {
            try await subscriptionManager.restorePurchases()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }
}

// MARK: - Account Settings

struct AccountSettingsView: View {
    @State private var authManager = AuthManager.shared
    @State private var showDeleteConfirmation = false
    @State private var isDeleting = false
    @State private var isUpdatingName = false
    @State private var feedbackMessage: String?
    @State private var editingName: String = ""
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            Section {
                LabeledContent {
                    HStack(spacing: 8) {
                        TextField("settings.account.defaultName", text: $editingName)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(.secondary)
                            .onSubmit {
                                Task { await updateName() }
                            }
                            .submitLabel(.done)
                            .disabled(isUpdatingName)

                        if isUpdatingName {
                            ProgressView()
                                .controlSize(.small)
                        } else {
                            Image(systemName: "pencil")
                                .foregroundStyle(.tertiary)
                                .font(.subheadline)
                        }
                    }
                } label: {
                    Label("settings.account.name", systemImage: "person")
                }

                LabeledContent {
                    Text(authManager.userEmail ?? "--")
                        .foregroundStyle(.secondary)
                } label: {
                    Label("settings.account.email", systemImage: "envelope")
                }
            } header: {
                Text("settings.account").textCase(nil)
            }
            
            Section {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    actionRow(
                        title: "settings.action.deleteAccount",
                        systemImage: "trash",
                        isLoading: isDeleting
                    )
                    .foregroundStyle(.primary)
                }
                .disabled(isDeleting)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editingName = authManager.userName ?? String(localized: "settings.account.defaultName", defaultValue: "灵魂旅人")
        }
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

    private func updateName() async {
        guard !editingName.isEmpty, editingName != authManager.userName else { return }
        isUpdatingName = true
        defer { isUpdatingName = false }
        
        do {
            try await authManager.updateUserName(editingName)
        } catch {
            feedbackMessage = error.localizedDescription
            // Revert on failure
            editingName = authManager.userName ?? String(localized: "settings.account.defaultName", defaultValue: "灵魂旅人")
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

private func actionRow(title: LocalizedStringKey, systemImage: String, isLoading: Bool, isProminent: Bool = false) -> some View {
    HStack(spacing: 12) {
        Label {
            Text(title)
                .fontWeight(isProminent ? .medium : .regular)
        } icon: {
            Image(systemName: systemImage)
        }
        Spacer()
        if isLoading {
            ProgressView()
                .controlSize(.small)
        }
    }
}

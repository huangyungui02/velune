import StoreKit
import SwiftUI

// MARK: - Settings

struct SettingsView: View {
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @State private var showSignOutConfirmation = false
    @State private var isSigningOut = false
    @State private var showPaywall = false
    @State private var showSignInSheet = false
    @State private var showFeedbackSheet = false
    @State private var signInSheetDescriptionKey = "paywall.restore.signInRequired.description"
    @State private var feedbackTitleKey = "settings.error.title"
    @State private var feedbackMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        ZStack {
            BackgroundView()

            List {
                Section {
                    if authManager.isAnonymous {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("settings.account.anonymous.title")
                                .font(.body)
                                .foregroundStyle(UITheme.primaryText)

                            AppleSignInSettingsRow { error in
                                showError(error)
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        NavigationLink {
                            AccountSettingsView()
                        } label: {
                            SettingsAccountRow(authManager: authManager)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    sectionHeader("settings.section.account")
                }

                Section {
                    LabeledContent {
                        Text(subscriptionPlanName)
                            .foregroundStyle(UITheme.secondaryText)
                    } label: {
                        settingsRowLabel("settings.billing.plan", systemImage: "crown")
                    }

                    if let renewalTimeText {
                        LabeledContent {
                            Text(renewalTimeText)
                                .font(.system(.body, design: .rounded).monospacedDigit())
                                .foregroundStyle(UITheme.secondaryText)
                        } label: {
                            settingsRowLabel("settings.billing.renewalTime", systemImage: "clock")
                        }
                    }

                    if shouldShowUpgradeRow {
                        Button {
                            showPaywall = true
                        } label: {
                            HStack(spacing: 10) {
                                settingsRowLabel("settings.billing.action.upgrade", systemImage: "arrow.up.circle")
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(UITheme.tertiaryText)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }

                    Button {
                        handleRestoreTap()
                    } label: {
                        HStack(spacing: 10) {
                            settingsRowLabel("settings.billing.action.restore", systemImage: "arrow.triangle.2.circlepath")
                            Spacer(minLength: 0)
                            if subscriptionManager.isRestoring {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(subscriptionManager.isRestoring || !subscriptionManager.isRevenueCatAvailable)
                } header: {
                    sectionHeader("settings.section.billing")
                } footer: {
                    if let billingFooterText {
                        Text(billingFooterText)
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)
                    }
                }

                Section {
                    Button {
                        showFeedbackSheet = true
                    } label: {
                        settingsRowLabel("settings.feedback.title", systemImage: "text.bubble")
                    }
                    .foregroundStyle(UITheme.primaryText)

                    Link(destination: AppLinks.contactEmail) {
                        settingsRowLabel("settings.link.contactSupport", systemImage: "envelope")
                    }
                    .foregroundStyle(UITheme.primaryText)

                    Button {
                        requestReview()
                    } label: {
                        settingsRowLabel("settings.rateApp", systemImage: "star")
                    }
                    .foregroundStyle(UITheme.primaryText)
                } header: {
                    sectionHeader("settings.section.support")
                }

                Section {
                    Link(destination: AppLinks.terms) {
                        settingsRowLabel("settings.link.terms", systemImage: "doc.text")
                    }
                    .foregroundStyle(UITheme.primaryText)

                    Link(destination: AppLinks.privacy) {
                        settingsRowLabel("settings.link.privacy", systemImage: "hand.raised")
                    }
                    .foregroundStyle(UITheme.primaryText)
                } header: {
                    sectionHeader("settings.section.legal")
                }

                Section {
                    LabeledContent {
                        Text(appVersion)
                            .foregroundStyle(UITheme.secondaryText)
                            .font(.system(.body, design: .rounded).monospacedDigit())
                    } label: {
                        settingsRowLabel("settings.version", systemImage: "info.circle")
                    }
                } header: {
                    sectionHeader("settings.section.about")
                }

                if !authManager.isAnonymous {
                    Section {
                        Button(role: .destructive) {
                            showSignOutConfirmation = true
                        } label: {
                            HStack(spacing: 10) {
                                settingsRowLabel("settings.action.signOut", systemImage: "rectangle.portrait.and.arrow.right")
                                Spacer(minLength: 0)
                                if isSigningOut {
                                    ProgressView()
                                        .controlSize(.small)
                                }
                            }
                        }
                        .disabled(isSigningOut)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .environment(\.defaultMinListRowHeight, 50)
            .tint(UITheme.primaryText)
            .modifier(SettingsListChrome())
        }
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
        .alert(LocalizedStringKey(feedbackTitleKey), isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
        .onAppear {
            Task {
                await subscriptionManager.refreshBillingState(force: true)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showFeedbackSheet) {
            FeedbackForm(
                title: "settings.feedback.title",
                prompt: "settings.feedback.prompt",
                placeholder: "settings.feedback.placeholder",
                onSubmit: { content in
                    try await AppFeedback.submit(content: content)
                },
                onSubmitted: {
                    showNotice(String(localized: "settings.feedback.submitted"))
                }
            )
        }
        .sheet(isPresented: $showSignInSheet) {
            SignInRequiredSheet(descriptionKey: LocalizedStringKey(signInSheetDescriptionKey))
        }
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .textCase(nil)
            .foregroundStyle(UITheme.tertiaryText)
    }

    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }

        do {
            let userId = AuthManager.shared.currentUserId?.uuidString
            try await AuthManager.shared.signOut()
            SyncStateStore.clear(userId: userId)
            dismiss()
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionManager.restorePurchases()
            await subscriptionManager.refreshBillingState(force: true)
        } catch {
            showError(error.localizedDescription)
        }
    }

    private func handleRestoreTap() {
        guard !authManager.isAnonymous else {
            presentSignInSheet(descriptionKey: "paywall.restore.signInRequired.description")
            return
        }

        Task { await restorePurchases() }
    }

    private var appVersion: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(short) (\(build))"
    }

    private var billingFooterText: String? {
        var lines: [String] = []
        if !subscriptionManager.isRevenueCatAvailable {
            lines.append(String(localized: "settings.billing.revenuecat.missingKey"))
        }
        if let billingError = subscriptionManager.lastErrorMessage, !billingError.isEmpty {
            lines.append(billingError)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private var shouldShowUpgradeRow: Bool {
        !subscriptionManager.isPremium
    }

    private var renewalTimeText: String? {
        guard subscriptionManager.isPremium,
              let renewalDate = subscriptionManager.entitlementExpiresAt
        else {
            return nil
        }

        return DateFormatter.localizedString(from: renewalDate, dateStyle: .medium, timeStyle: .none)
    }

    private var subscriptionPlanName: String {
        NSLocalizedString(subscriptionManager.currentPlan.localizedNameKey, comment: "")
    }

    private func presentSignInSheet(descriptionKey: String) {
        signInSheetDescriptionKey = descriptionKey
        showSignInSheet = true
    }

    private func showError(_ message: String) {
        feedbackTitleKey = "settings.error.title"
        feedbackMessage = message
    }

    private func showNotice(_ message: String) {
        feedbackTitleKey = "settings.notice.title"
        feedbackMessage = message
    }

}



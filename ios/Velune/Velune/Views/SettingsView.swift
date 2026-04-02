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
    @State private var showStardustInfo = false
    @State private var showSignInSheet = false
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
                                feedbackMessage = error
                            }
                        }
                        .padding(.vertical, 4)
                    } else {
                        NavigationLink {
                            AccountSettingsView()
                        } label: {
                            accountRow
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    sectionHeader("settings.section.account")
                }

                Section {
                    HStack(spacing: 10) {
                        HStack(spacing: 8) {
                            settingsRowLabel("settings.billing.credits", systemImage: "sparkle")
                            Button {
                                showStardustInfo = true
                            } label: {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(UITheme.tertiaryText)
                                    .padding(4)
                            }
                            .buttonStyle(.plain)
                            .popover(isPresented: $showStardustInfo, arrowEdge: .top) {
                                stardustInfoPopover
                            }
                        }
                        Spacer(minLength: 0)
                        stardustAccessView
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
                                settingsRowLabel("settings.billing.action.upgrade", systemImage: "crown")
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .medium))
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
                            settingsRowLabel("settings.billing.action.restore", systemImage: "arrow.clockwise")
                            Spacer(minLength: 0)
                            if subscriptionManager.isRestoring {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
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
        .alert("settings.error.title", isPresented: Binding(
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
        .sheet(isPresented: $showSignInSheet) {
            SignInRequiredSheet(descriptionKey: "paywall.restore.signInRequired.description")
        }
    }

    private var accountRow: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(.white.opacity(0.09))
                    .frame(width: 44, height: 44)

                Image(systemName: "person.crop.circle")
                    .font(.system(size: 23))
                    .foregroundStyle(UITheme.primaryText.opacity(0.9))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(
                    authManager.userName
                        ?? String(
                            localized: "settings.account.defaultName",
                            defaultValue: "Soul Traveler"
                        )
                )
                .font(.headline)
                .foregroundStyle(UITheme.primaryText)

                if let email = authManager.userEmail {
                    Text(email)
                        .font(.subheadline)
                        .foregroundStyle(UITheme.secondaryText)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
        }
        .padding(.vertical, 4)
    }

    private func sectionHeader(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .textCase(nil)
            .foregroundStyle(UITheme.tertiaryText)
    }

    private var stardustInfoPopover: some View {
        ScrollView {
            Text(stardustInfoDescriptionKey)
                .font(.subheadline)
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .frame(width: 320, alignment: .topLeading)
        .frame(maxHeight: 360, alignment: .topLeading)
        .presentationCompactAdaptation(.popover)
    }

    private func signOut() async {
        isSigningOut = true
        defer { isSigningOut = false }

        do {
            let userId = AuthManager.shared.currentUserId?.uuidString
            try await AuthManager.shared.signOut()
            PaginationStateStore.clearGlimmerBottom(userId: userId)
            dismiss()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }

    private func restorePurchases() async {
        do {
            try await subscriptionManager.restorePurchases()
            await subscriptionManager.refreshBillingState(force: true)
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }

    private func handleRestoreTap() {
        guard !authManager.isAnonymous else {
            showSignInSheet = true
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

    private var stardustInfoDescriptionKey: LocalizedStringKey {
        subscriptionManager.isPremium
            ? "settings.billing.stardust.description.premium"
            : "settings.billing.stardust.description"
    }

    private var stardustAccessView: some View {
        Text("\(subscriptionManager.credits)")
            .font(.system(.title3, design: .rounded).monospacedDigit())
            .fontWeight(.semibold)
            .foregroundStyle(UITheme.primaryText)
    }
}

private struct SettingsListChrome: ViewModifier {
    func body(content: Content) -> some View {
        content
            .listRowBackground(Color.white.opacity(0.05))
            .listRowSeparatorTint(.white.opacity(0.08))
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
                            .foregroundStyle(.primary)
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
                    settingsRowLabel("settings.account.name", systemImage: "person")
                }

                LabeledContent {
                    Text(authManager.userEmail ?? "--")
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                } label: {
                    settingsRowLabel("settings.account.email", systemImage: "envelope")
                }
            } header: {
                Text("settings.section.profile")
                    .textCase(nil)
            }

            Section {
                Button {
                    showDeleteConfirmation = true
                } label: {
                    HStack(spacing: 10) {
                        settingsRowLabel("settings.action.deleteAccount", systemImage: "trash")
                        Spacer(minLength: 0)
                        if isDeleting {
                            ProgressView()
                                .controlSize(.small)
                        }
                    }
                }
                .disabled(isDeleting)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("settings.account")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            editingName = authManager.userName ?? String(
                localized: "settings.account.defaultName",
                defaultValue: "Soul Traveler"
            )
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
            editingName = authManager.userName ?? String(
                localized: "settings.account.defaultName",
                defaultValue: "Soul Traveler"
            )
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }

        do {
            let userId = AuthManager.shared.currentUserId?.uuidString
            try await AuthManager.shared.deleteAccount()
            PaginationStateStore.clearGlimmerBottom(userId: userId)
            SidebarSyncStateStore.clear(userId: userId)
            if let userId {
                try SidebarResonanceStore.clear(userId: userId, context: modelContext)
            }
            try modelContext.delete(model: Glimmer.self)
            try modelContext.delete(model: Echo.self)
            dismiss()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }
}

// MARK: - Shared Components

private func settingsRowLabel(_ title: LocalizedStringKey, systemImage: String) -> some View {
    Label {
        Text(title)
            .foregroundStyle(UITheme.primaryText)
            .lineLimit(1)
    } icon: {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .medium))
            .foregroundStyle(UITheme.secondaryText)
            .frame(width: 20)
    }
}

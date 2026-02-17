import StoreKit
import SwiftUI

struct SettingsView: View {
    @State private var showSignOutConfirmation = false
    @State private var showDeleteAccountConfirmation = false
    @State private var isSigningOut = false
    @State private var isDeletingAccount = false
    @State private var feedbackMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        List {
            Section(generalSectionTitle) {
                Button {
                    openNotificationSettings()
                } label: {
                    HStack {
                        Label(notificationsText, systemImage: "bell.badge")
                        Spacer()
                        Image(systemName: "arrow.up.forward")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }

            Section(supportSectionTitle) {
                Link(destination: AppLinks.supportEmail) {
                    Label(contactSupportText, systemImage: "envelope")
                }

                Button {
                    requestReview()
                } label: {
                    Label(rateAppText, systemImage: "star")
                }
            }

            Section(legalSectionTitle) {
                Link(destination: AppLinks.terms) {
                    Label(termsText, systemImage: "doc.text")
                }

                Link(destination: AppLinks.privacy) {
                    Label(privacyText, systemImage: "hand.raised")
                }
            }

            Section(aboutSectionTitle) {
                LabeledContent {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                } label: {
                    Label(versionText, systemImage: "app.badge")
                }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    rowLabel(
                        title: signOutText,
                        systemImage: "rectangle.portrait.and.arrow.right",
                        showsLoading: isSigningOut
                    )
                }
                .disabled(isBusy)
            }

            Section {
                Button(role: .destructive) {
                    showDeleteAccountConfirmation = true
                } label: {
                    rowLabel(
                        title: deleteAccountText,
                        systemImage: "trash",
                        showsLoading: isDeletingAccount
                    )
                }
                .disabled(isBusy)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(settingsTitle)
        .navigationBarTitleDisplayMode(.inline)
        .alert(signOutConfirmationTitle, isPresented: $showSignOutConfirmation) {
            Button(signOutText, role: .destructive) {
                Task {
                    await signOut()
                }
            }
            Button(cancelText, role: .cancel) {}
        } message: {
            Text(signOutConfirmationMessage)
        }
        .alert(deleteConfirmationTitle, isPresented: $showDeleteAccountConfirmation) {
            Button(deleteAccountText, role: .destructive) {
                Task {
                    await deleteAccount()
                }
            }
            Button(cancelText, role: .cancel) {}
        } message: {
            Text(deleteConfirmationMessage)
        }
        .alert(errorTitle, isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { isPresented in
                if !isPresented {
                    feedbackMessage = nil
                }
            }
        )) {
            Button(okText, role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
    }

    // MARK: - Actions

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

    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }

        do {
            try await AuthManager.shared.deleteAccount()
            dismiss()
        } catch {
            feedbackMessage = error.localizedDescription
        }
    }

    private func openNotificationSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    @ViewBuilder
    private func rowLabel(title: String, systemImage: String, showsLoading: Bool) -> some View {
        HStack(spacing: 12) {
            Label(title, systemImage: systemImage)
            Spacer()
            if showsLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var isBusy: Bool {
        isSigningOut || isDeletingAccount
    }

    private var appVersion: String {
        let shortVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(shortVersion) (\(build))"
    }

    // MARK: - Localized Strings

    private var settingsTitle: String { String(localized: "settings.title") }
    private var generalSectionTitle: String { String(localized: "settings.section.general") }
    private var legalSectionTitle: String { String(localized: "settings.section.legal") }
    private var supportSectionTitle: String { String(localized: "settings.section.support") }
    private var aboutSectionTitle: String { String(localized: "settings.section.about") }
    private var notificationsText: String { String(localized: "settings.notifications") }
    private var rateAppText: String { String(localized: "settings.rateApp") }
    private var signOutText: String { String(localized: "settings.action.signOut") }
    private var deleteAccountText: String { String(localized: "settings.action.deleteAccount") }
    private var termsText: String { String(localized: "settings.link.terms") }
    private var privacyText: String { String(localized: "settings.link.privacy") }
    private var contactSupportText: String { String(localized: "settings.link.contactSupport") }
    private var versionText: String { String(localized: "settings.version") }
    private var cancelText: String { String(localized: "common.cancel") }
    private var okText: String { String(localized: "common.ok") }
    private var errorTitle: String { String(localized: "settings.error.title") }
    private var signOutConfirmationTitle: String { String(localized: "settings.signOut.confirm.title") }
    private var signOutConfirmationMessage: String { String(localized: "settings.signOut.confirm.message") }
    private var deleteConfirmationTitle: String { String(localized: "settings.delete.confirm.title") }
    private var deleteConfirmationMessage: String { String(localized: "settings.delete.confirm.message") }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

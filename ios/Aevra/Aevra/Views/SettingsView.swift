import StoreKit
import SwiftData
import SwiftUI

// MARK: - Settings

struct SettingsView: View {
    @State private var showSignOutConfirmation = false
    @State private var isSigningOut = false
    @State private var feedbackMessage: String?
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.systemDefault.rawValue
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        List {
            Section(L10n.string("settings.section.account")) {
                NavigationLink {
                    AccountSettingsView()
                } label: {
                    Label(L10n.string("settings.account"), systemImage: "person.crop.circle")
                }
            }

            Section(L10n.string("settings.section.language")) {
                LabeledContent {
                    Picker("", selection: $appLanguageRawValue) {
                        Text(L10n.string("settings.language.english"))
                            .tag(AppLanguage.english.rawValue)
                        Text(L10n.string("settings.language.simplifiedChinese"))
                            .tag(AppLanguage.simplifiedChinese.rawValue)
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                } label: {
                    Label(L10n.string("settings.language"), systemImage: "globe")
                }
            }

            Section(L10n.string("settings.section.support")) {
                Link(destination: AppLinks.contactEmail) {
                    Label(L10n.string("settings.link.contactSupport"), systemImage: "envelope")
                }

                Button {
                    requestReview()
                } label: {
                    Label(L10n.string("settings.rateApp"), systemImage: "star")
                }
            }

            Section(L10n.string("settings.section.legal")) {
                Link(destination: AppLinks.terms) {
                    Label(L10n.string("settings.link.terms"), systemImage: "doc.text")
                }

                Link(destination: AppLinks.privacy) {
                    Label(L10n.string("settings.link.privacy"), systemImage: "hand.raised")
                }
            }

            Section(L10n.string("settings.section.about")) {
                LabeledContent {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                } label: {
                    Label(L10n.string("settings.version"), systemImage: "app.badge")
                }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    actionRow(
                        title: L10n.string("settings.action.signOut"),
                        systemImage: "rectangle.portrait.and.arrow.right",
                        isLoading: isSigningOut
                    )
                }
                .disabled(isSigningOut)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.string("settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.string("settings.signOut.confirm.title"), isPresented: $showSignOutConfirmation) {
            Button(L10n.string("settings.action.signOut"), role: .destructive) {
                Task { await signOut() }
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("settings.signOut.confirm.message"))
        }
        .alert(L10n.string("settings.error.title"), isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button(L10n.string("common.ok"), role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
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
                        title: L10n.string("settings.action.deleteAccount"),
                        systemImage: "trash",
                        isLoading: isDeleting
                    )
                }
                .disabled(isDeleting)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(L10n.string("settings.account"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(L10n.string("settings.delete.confirm.title"), isPresented: $showDeleteConfirmation) {
            Button(L10n.string("settings.action.deleteAccount"), role: .destructive) {
                Task { await deleteAccount() }
            }
            Button(L10n.string("common.cancel"), role: .cancel) {}
        } message: {
            Text(L10n.string("settings.delete.confirm.message"))
        }
        .alert(L10n.string("settings.error.title"), isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button(L10n.string("common.ok"), role: .cancel) {}
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

private func actionRow(title: String, systemImage: String, isLoading: Bool) -> some View {
    HStack(spacing: 12) {
        Label(title, systemImage: systemImage)
        Spacer()
        if isLoading {
            ProgressView()
                .controlSize(.small)
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
}

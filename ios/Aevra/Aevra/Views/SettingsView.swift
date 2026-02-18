import StoreKit
import SwiftData
import SwiftUI

// MARK: - Settings

struct SettingsView: View {
    @State private var showSignOutConfirmation = false
    @State private var isSigningOut = false
    @State private var feedbackMessage: String?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview

    var body: some View {
        List {
            Section(String(localized: "settings.section.account")) {
                NavigationLink {
                    AccountSettingsView()
                } label: {
                    Label(String(localized: "settings.account"), systemImage: "person.crop.circle")
                }
            }

            Section(String(localized: "settings.section.support")) {
                Link(destination: AppLinks.contactEmail) {
                    Label(String(localized: "settings.link.contactSupport"), systemImage: "envelope")
                }

                Button {
                    requestReview()
                } label: {
                    Label(String(localized: "settings.rateApp"), systemImage: "star")
                }
            }

            Section(String(localized: "settings.section.legal")) {
                Link(destination: AppLinks.terms) {
                    Label(String(localized: "settings.link.terms"), systemImage: "doc.text")
                }

                Link(destination: AppLinks.privacy) {
                    Label(String(localized: "settings.link.privacy"), systemImage: "hand.raised")
                }
            }

            Section(String(localized: "settings.section.about")) {
                LabeledContent {
                    Text(appVersion)
                        .foregroundStyle(.secondary)
                } label: {
                    Label(String(localized: "settings.version"), systemImage: "app.badge")
                }
            }

            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    actionRow(
                        title: String(localized: "settings.action.signOut"),
                        systemImage: "rectangle.portrait.and.arrow.right",
                        isLoading: isSigningOut
                    )
                }
                .disabled(isSigningOut)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "settings.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "settings.signOut.confirm.title"), isPresented: $showSignOutConfirmation) {
            Button(String(localized: "settings.action.signOut"), role: .destructive) {
                Task { await signOut() }
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.signOut.confirm.message"))
        }
        .alert(String(localized: "settings.error.title"), isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
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
                        title: String(localized: "settings.action.deleteAccount"),
                        systemImage: "trash",
                        isLoading: isDeleting
                    )
                }
                .disabled(isDeleting)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(String(localized: "settings.account"))
        .navigationBarTitleDisplayMode(.inline)
        .alert(String(localized: "settings.delete.confirm.title"), isPresented: $showDeleteConfirmation) {
            Button(String(localized: "settings.action.deleteAccount"), role: .destructive) {
                Task { await deleteAccount() }
            }
            Button(String(localized: "common.cancel"), role: .cancel) {}
        } message: {
            Text(String(localized: "settings.delete.confirm.message"))
        }
        .alert(String(localized: "settings.error.title"), isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
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

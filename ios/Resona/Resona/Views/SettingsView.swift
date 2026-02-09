import SwiftUI

struct SettingsView: View {
    @State private var showSignOutConfirmation = false
    @State private var isSigningOut = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section {
                Button(role: .destructive) {
                    showSignOutConfirmation = true
                } label: {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                        Text("Sign out")
                    }
                }
                .disabled(isSigningOut)
            }
        }
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Are you sure you want to sign out?", isPresented: $showSignOutConfirmation) {
            Button("Sign out", role: .destructive) {
                Task {
                    await signOut()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("You’ll need to sign in again to continue using the app.")
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
            print("Sign out failed: \(error.localizedDescription)")
        }
    }
}

#Preview {
    NavigationStack {
        SettingsView()
    }
    .preferredColorScheme(.dark)
}

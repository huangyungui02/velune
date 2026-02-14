import Combine
import Foundation
import Supabase

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()
    
    var isAuthenticated: Bool = false
    
    private var currentUser: User?
    private var authStateChangeTask: Task<Void, Never>?
    
    private init() {
        checkInitialAuthState()
        observeAuthStateChanges()
    }
    
    private func checkInitialAuthState() {
        if let session = supabase.auth.currentSession {
            isAuthenticated = true
            currentUser = session.user
        } else {
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    private func observeAuthStateChanges() {
        authStateChangeTask = Task {
            for await (_, session) in supabase.auth.authStateChanges {
                if let session = session, !session.isExpired {
                    self.isAuthenticated = true
                    self.currentUser = session.user
                } else {
                    self.isAuthenticated = false
                    self.currentUser = nil
                }
            }
        }
    }
    
    func getUserId() throws -> UUID {
        guard let userId = currentUser?.id else {
            throw AppError.unauthenticated
        }
        return userId
    }
    
    func signOut() async throws {
        try await supabase.auth.signOut()
    }

    func deleteAccount() async throws {
        try await supabase
            .rpc("delete_own_account")
            .execute()

        // The auth user is already removed. Sign out locally to clear any cached session.
        do {
            try await supabase.auth.signOut()
        } catch {
            // Ignore sign-out failures after deletion and force local auth state reset.
        }

        isAuthenticated = false
        currentUser = nil
    }
}

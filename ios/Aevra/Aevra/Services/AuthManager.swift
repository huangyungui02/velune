import Combine
import Foundation
import AuthenticationServices
import Supabase

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()
    
    var isAuthenticated: Bool = false
    var isAnonymous: Bool = false
    
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
            isAnonymous = session.user.isAnonymous
        } else {
            isAuthenticated = false
            currentUser = nil
            isAnonymous = false
        }
    }
    
    private func observeAuthStateChanges() {
        authStateChangeTask = Task {
            for await (_, session) in supabase.auth.authStateChanges {
                if let session = session, !session.isExpired {
                    self.isAuthenticated = true
                    self.currentUser = session.user
                    self.isAnonymous = session.user.isAnonymous
                } else {
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.isAnonymous = false
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

    func signInAnonymously() async throws {
        _ = try await supabase.auth.signInAnonymously()
    }

    func signInWithAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async throws {
        guard let idToken = credential.identityToken
            .flatMap({ String(data: $0, encoding: .utf8) })
        else {
            throw AppError.unauthenticated
        }

        let credentials = OpenIDConnectCredentials(
            provider: .apple,
            idToken: idToken
        )

        if isAnonymous {
            do {
                _ = try await supabase.auth.linkIdentityWithIdToken(credentials: credentials)
            } catch {
                _ = try await supabase.auth.signInWithIdToken(credentials: credentials)
            }
        } else {
            _ = try await supabase.auth.signInWithIdToken(credentials: credentials)
        }

        try await updateUserMetadataIfAvailable(from: credential)
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
        isAnonymous = false
    }

    private func updateUserMetadataIfAvailable(from credential: ASAuthorizationAppleIDCredential) async throws {
        guard let fullName = credential.fullName else { return }

        var nameParts: [String] = []
        if let givenName = fullName.givenName {
            nameParts.append(givenName)
        }
        if let middleName = fullName.middleName {
            nameParts.append(middleName)
        }
        if let familyName = fullName.familyName {
            nameParts.append(familyName)
        }

        let fullNameString = nameParts.joined(separator: " ")

        try await supabase.auth.update(
            user: UserAttributes(
                data: [
                    "full_name": .string(fullNameString),
                    "given_name": .string(fullName.givenName ?? ""),
                    "family_name": .string(fullName.familyName ?? "")
                ]
            )
        )
    }
}

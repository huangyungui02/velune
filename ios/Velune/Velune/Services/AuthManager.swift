import Combine
import Foundation
import AuthenticationServices
import OSLog
import Supabase

@MainActor
@Observable
final class AuthManager {
    static let shared = AuthManager()
    private let logger = AppLogger.auth

    var isAuthenticated: Bool = false
    var isAnonymous: Bool = false
    var currentUserId: UUID? { currentUser?.id }
    var currentAccessToken: String? { Backend.supabaseIfAvailable?.auth.currentSession?.accessToken }
    var userEmail: String? { currentUser?.email }
    var userName: String? {
        if let metadata = currentUser?.userMetadata,
           case let .string(name) = metadata["nickname"],
           !name.isEmpty {
            return name
        }
        return nil
    }

    private var currentUser: User?
    private var authStateChangeTask: Task<Void, Never>?
    private var installationBindingSyncState: InstallationBindingSyncState?

    private init() {
        checkInitialAuthState()
        observeAuthStateChanges()
    }

    private func checkInitialAuthState() {
        guard let supabase = Backend.supabaseIfAvailable else {
            resetAuthState()
            return
        }

        if let session = supabase.auth.currentSession {
            applyAuthenticatedSession(session)
        } else {
            resetAuthState()
        }
    }

    private func observeAuthStateChanges() {
        guard let supabase = Backend.supabaseIfAvailable else {
            logger.error("auth observation unavailable: backend is not configured")
            return
        }

        authStateChangeTask = Task {
            for await (_, session) in supabase.auth.authStateChanges {
                if let session = session, !session.isExpired {
                    self.applyAuthenticatedSession(session)
                    try? await self.upsertInstallationBinding(
                        userId: session.user.id
                    )
                } else {
                    self.resetAuthState()
                    self.installationBindingSyncState = nil
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
        let supabase = try Backend.requireSupabase()

        if isAnonymous {
            try await supabase.auth.signOut(scope: .local)
        } else {
            try await supabase.auth.signOut()
        }
        installationBindingSyncState = nil
    }

    func signInAnonymously() async throws {
        let supabase = try Backend.requireSupabase()

        if let restoredSession = await restoreAnonymousSessionIfAvailable() {
            try await upsertInstallationBinding(
                userId: restoredSession.user.id,
                force: true
            )
            return
        }

        let session = try await supabase.auth.signInAnonymously()
        cacheAnonymousRefreshToken(from: session)
        try await upsertInstallationBinding(
            userId: session.user.id,
            force: true
        )
    }

    func signInWithAppleCredential(_ credential: ASAuthorizationAppleIDCredential) async throws {
        let supabase = try Backend.requireSupabase()

        guard let idToken = credential.identityToken
            .flatMap({ String(data: $0, encoding: .utf8) })
        else {
            throw AppError.unauthenticated
        }

        let credentials = OpenIDConnectCredentials(
            provider: .apple,
            idToken: idToken
        )

        _ = try await supabase.auth.signInWithIdToken(credentials: credentials)
    }

    func deleteAccount() async throws {
        let supabase = try Backend.requireSupabase()

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
        AnonymousRefreshTokenStore.clear()
        installationBindingSyncState = nil
    }

    func updateUserName(_ name: String) async throws {
        let supabase = try Backend.requireSupabase()
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let response = try await supabase.auth.update(
            user: UserAttributes(
                data: [
                    "nickname": .string(trimmedName),
                    "full_name": .null,
                    "given_name": .null,
                    "family_name": .null
                ]
            )
        )
        self.currentUser = response
    }

    private func restoreAnonymousSessionIfAvailable() async -> Session? {
        guard let supabase = Backend.supabaseIfAvailable else {
            logger.error("anonymous session restore unavailable: backend is not configured")
            return nil
        }

        guard let refreshToken = AnonymousRefreshTokenStore.read(),
              !refreshToken.isEmpty
        else {
            return nil
        }

        do {
            let session = try await supabase.auth.refreshSession(refreshToken: refreshToken)
            guard session.user.isAnonymous else {
                AnonymousRefreshTokenStore.clear()
                return nil
            }

            cacheAnonymousRefreshToken(from: session)
            return session
        } catch {
            AnonymousRefreshTokenStore.clear()
            logger.notice("anonymous session restore skipped: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func upsertInstallationBinding(
        userId: UUID,
        force: Bool = false
    ) async throws {
        let syncState = InstallationBindingSyncState(
            userId: userId
        )

        if !force, installationBindingSyncState == syncState {
            return
        }

        let params: [String: AnyJSON] = [
            "p_installation_id": .string(InstallationIDStore.getOrCreateInstallationID())
        ]

        let supabase = try Backend.requireSupabase()
        try await supabase
            .rpc("upsert_installation_for_current_user", params: params)
            .execute()

        installationBindingSyncState = syncState
    }

    private func applyAuthenticatedSession(_ session: Session) {
        isAuthenticated = true
        currentUser = session.user
        isAnonymous = session.user.isAnonymous
        if session.user.isAnonymous {
            cacheAnonymousRefreshToken(from: session)
        }
    }

    private func resetAuthState() {
        isAuthenticated = false
        currentUser = nil
        isAnonymous = false
    }

    private func cacheAnonymousRefreshToken(from session: Session) {
        guard session.user.isAnonymous else {
            return
        }

        let token = session.refreshToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            return
        }

        _ = AnonymousRefreshTokenStore.save(token)
    }
}

private struct InstallationBindingSyncState: Equatable {
    let userId: UUID
}

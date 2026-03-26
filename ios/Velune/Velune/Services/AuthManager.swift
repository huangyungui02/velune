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
    var currentUserId: UUID? { currentUser?.id }
    var currentAccessToken: String? { supabase.auth.currentSession?.accessToken }
    var userEmail: String? { currentUser?.email }
    var userName: String? {
        if let metadata = currentUser?.userMetadata,
           case let .string(name) = metadata["full_name"],
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
                    try? await self.upsertInstallationBinding(
                        userId: session.user.id,
                        isAnonymous: session.user.isAnonymous,
                        refreshToken: session.user.isAnonymous ? session.refreshToken : nil
                    )
                } else {
                    self.isAuthenticated = false
                    self.currentUser = nil
                    self.isAnonymous = false
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
        if isAnonymous {
            try await supabase.auth.signOut(scope: .local)
        } else {
            try await supabase.auth.signOut()
        }
        installationBindingSyncState = nil
    }

    func signInAnonymously() async throws {
        let installationId = InstallationIDStore.getOrCreateInstallationID()

        if let restoredSession = await restoreAnonymousSessionIfAvailable(
            installationId: installationId
        ) {
            try await upsertInstallationBinding(
                userId: restoredSession.user.id,
                isAnonymous: true,
                refreshToken: restoredSession.refreshToken,
                force: true
            )
            return
        }

        let session = try await supabase.auth.signInAnonymously()
        try await upsertInstallationBinding(
            userId: session.user.id,
            isAnonymous: true,
            refreshToken: session.refreshToken,
            force: true
        )
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

        if let session = supabase.auth.currentSession {
            try await upsertInstallationBinding(
                userId: session.user.id,
                isAnonymous: false,
                refreshToken: nil,
                force: true
            )
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
        installationBindingSyncState = nil
    }

    func updateUserName(_ name: String) async throws {
        let response = try await supabase.auth.update(
            user: UserAttributes(
                data: [
                    "full_name": .string(name)
                ]
            )
        )
        self.currentUser = response
    }

    private func restoreAnonymousSessionIfAvailable(installationId: String) async -> Session? {
        let params: [String: AnyJSON] = [
            "p_installation_id": .string(installationId)
        ]

        do {
            let rows: [AnonymousInstallationSession] = try await supabase
                .rpc("get_installation_anonymous_session", params: params)
                .execute()
                .value

            guard let row = rows.first else {
                return nil
            }

            let session = try await supabase.auth.refreshSession(refreshToken: row.refreshToken)
            guard session.user.isAnonymous, session.user.id == row.userId else {
                return nil
            }

            return session
        } catch {
            return nil
        }
    }

    private func upsertInstallationBinding(
        userId: UUID,
        isAnonymous: Bool,
        refreshToken: String?,
        force: Bool = false
    ) async throws {
        let syncState = InstallationBindingSyncState(
            userId: userId,
            isAnonymous: isAnonymous,
            refreshToken: refreshToken
        )

        if !force, installationBindingSyncState == syncState {
            return
        }

        let params: [String: AnyJSON] = [
            "p_installation_id": .string(InstallationIDStore.getOrCreateInstallationID()),
            "p_is_anonymous": .bool(syncState.isAnonymous),
            "p_refresh_token": syncState.refreshToken.map(AnyJSON.string) ?? .null
        ]

        try await supabase
            .rpc("upsert_installation_for_current_user", params: params)
            .execute()

        installationBindingSyncState = syncState
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

private struct AnonymousInstallationSession: Decodable, Sendable {
    let userId: UUID
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case refreshToken = "refresh_token"
    }
}

private struct InstallationBindingSyncState: Equatable {
    let userId: UUID
    let isAnonymous: Bool
    let refreshToken: String?
}

import SwiftUI
import OSLog

enum ChatCachePolicy {
    static let sessionPageSize = 20
    static let messageSessionCapacity = 50
}

extension ChatView {
    var selectedSessionId: UUID {
        activeSessionId
    }

    var conversationSessions: [ChatSession] {
        sessions
    }

    @MainActor
    func loadConversationSessions() async {
        guard let userId = AuthManager.shared.currentUserId?.uuidString else {
            sessions = []
            sessionMenuError = nil
            return
        }

        _ = loadLocalConversationSessions(userId: userId)
    }

    @MainActor
    func syncConversationSessionsOnMenuAppear() async {
        if isLoadingSessions { return }
        isLoadingSessions = true
        defer { isLoadingSessions = false }

        guard let userId = AuthManager.shared.currentUserId?.uuidString else {
            sessions = []
            sessionMenuError = nil
            return
        }

        let hasLocalCache = !sessions.isEmpty || loadLocalConversationSessions(userId: userId)
        await syncConversationSessions(userId: userId, hasLocalCache: hasLocalCache)
    }

    @MainActor
    @discardableResult
    func loadLocalConversationSessions(userId: String) -> Bool {
        do {
            sessions = try ChatSession.fetchCached(
                userId: userId,
                soulerId: soulerId,
                context: modelContext
            )
            if !sessions.isEmpty {
                sessionMenuError = nil
            }
            return !sessions.isEmpty
        } catch {
            logger.notice("reading session cache failed: \(error.localizedDescription, privacy: .public)")
            sessions = []
            return false
        }
    }

    @MainActor
    func syncConversationSessions(userId: String, hasLocalCache: Bool) async {
        do {
            let remoteSessions: [ChatSession]
            if hasLocalCache {
                remoteSessions = try await ChatSession.getPage(
                    soulerId: soulerId,
                    limit: ChatCachePolicy.sessionPageSize,
                    offset: 0
                )
            } else {
                remoteSessions = try await ChatSession.getAll(
                    soulerId: soulerId,
                    pageSize: ChatCachePolicy.sessionPageSize
                )
            }

            let hasChanges = try ChatSession.mergeCached(
                remoteSessions,
                userId: userId,
                context: modelContext
            )

            if hasChanges || sessions.isEmpty {
                sessions = try ChatSession.fetchCached(
                    userId: userId,
                    soulerId: soulerId,
                    context: modelContext
                )
            }

            sessionMenuError = nil
        } catch {
            if !hasLocalCache && sessions.isEmpty {
                sessionMenuError = error.localizedDescription
            }
        }
    }

    @MainActor
    func mergeConversationSessionCacheIfPossible(_ sessionsToMerge: [ChatSession]) {
        guard let userId = AuthManager.shared.currentUserId?.uuidString else { return }
        guard !sessionsToMerge.isEmpty else { return }

        do {
            let hasChanges = try ChatSession.mergeCached(
                sessionsToMerge,
                userId: userId,
                context: modelContext
            )
            if hasChanges || sessions.isEmpty {
                sessions = try ChatSession.fetchCached(
                    userId: userId,
                    soulerId: soulerId,
                    context: modelContext
                )
            }
        } catch {
            logger.notice("writing session cache failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    func cacheMessagesIfPossible(
        _ messagesToCache: [Message],
        sessionId: UUID,
        fallbackSessionUpdatedAt: Date
    ) {
        guard let userId = AuthManager.shared.currentUserId?.uuidString else { return }

        let sessionUpdatedAt = sessions
            .first(where: { $0.id == sessionId })?
            .updatedAt ?? fallbackSessionUpdatedAt

        do {
            try Message.replaceCached(
                messages: messagesToCache,
                sessionId: sessionId,
                userId: userId,
                sessionUpdatedAt: sessionUpdatedAt,
                capacity: ChatCachePolicy.messageSessionCapacity,
                context: modelContext
            )
        } catch {
            logger.notice("writing message cache failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}

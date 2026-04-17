import SwiftUI
import OSLog

extension ChatView {
    @MainActor
    func loadMessages() async {
        if isDraftSession {
            messages = []
            return
        }
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }

        let sessionId = activeSessionId
        let sessionUpdatedAt = sessions.first(where: { $0.id == sessionId })?.updatedAt
        var hasUsableCache = false
        var cachedMessages: [Message] = []
        var cachedBucket: MessageCacheBucket?
        var shouldRefreshFromRemote = true
        let userId = AuthManager.shared.currentUserId?.uuidString

        if let userId {
            do {
                cachedBucket = try Message.fetchBucket(
                    sessionId: sessionId,
                    userId: userId,
                    context: modelContext
                )

                cachedMessages = try Message.fetchCached(
                    sessionId: sessionId,
                    userId: userId,
                    context: modelContext
                )
                if !cachedMessages.isEmpty {
                    messages = cachedMessages
                    hasUsableCache = true
                    errorMessage = nil
                    billingErrorContext = nil
                }

                shouldRefreshFromRemote = try Message.shouldRefreshCache(
                    sessionId: sessionId,
                    userId: userId,
                    sessionUpdatedAt: sessionUpdatedAt,
                    context: modelContext
                )

                if !hasUsableCache && !shouldRefreshFromRemote {
                    shouldRefreshFromRemote = true
                }
            } catch {
                logger.notice("reading message cache failed: \(error.localizedDescription, privacy: .public)")
            }
        }

        guard shouldRefreshFromRemote else { return }

        do {
            if let cachedBucket, hasUsableCache {
                let latestCachedCreatedAt = cachedMessages.last?.createdAt ?? cachedBucket.lastSyncedAt
                let incrementalMessages = try await Message.getHistory(
                    sessionId: sessionId,
                    createdAfterOrAt: max(cachedBucket.lastSyncedAt, latestCachedCreatedAt)
                )

                if incrementalMessages.isEmpty,
                   let sessionUpdatedAt,
                   cachedBucket.lastSessionUpdatedAt < sessionUpdatedAt {
                    let remoteMessages = try await Message.getHistory(sessionId: sessionId)
                    messages = remoteMessages
                    cacheMessagesIfPossible(
                        remoteMessages,
                        sessionId: sessionId,
                        fallbackSessionUpdatedAt: sessionUpdatedAt
                    )
                } else if !incrementalMessages.isEmpty {
                    let mergedMessages = mergeMessages(cachedMessages, with: incrementalMessages)
                    messages = mergedMessages
                    cacheMessagesIfPossible(
                        mergedMessages,
                        sessionId: sessionId,
                        fallbackSessionUpdatedAt: sessionUpdatedAt ?? Date.now
                    )
                }

                errorMessage = nil
                billingErrorContext = nil
                return
            }

            let remoteMessages = try await Message.getHistory(sessionId: sessionId)
            messages = remoteMessages
            errorMessage = nil
            billingErrorContext = nil

            cacheMessagesIfPossible(
                remoteMessages,
                sessionId: sessionId,
                fallbackSessionUpdatedAt: sessionUpdatedAt ?? Date.now
            )
        } catch {
            guard !hasUsableCache else {
                logger.notice("message refresh failed, using cached copy: \(error.localizedDescription, privacy: .public)")
                return
            }
            errorMessage = error.localizedDescription
            billingErrorContext = error.billingErrorContext
        }
    }

    func mergeMessages(_ cached: [Message], with incremental: [Message]) -> [Message] {
        guard !incremental.isEmpty else { return cached }

        var mergedById = Dictionary(uniqueKeysWithValues: cached.map { ($0.id, $0) })
        for message in incremental {
            mergedById[message.id] = message
        }

        return mergedById.values.sorted { lhs, rhs in
            if lhs.createdAt == rhs.createdAt {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.createdAt < rhs.createdAt
        }
    }
}

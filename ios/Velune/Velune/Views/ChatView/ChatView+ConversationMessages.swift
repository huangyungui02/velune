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
        var shouldRefreshFromRemote = true
        let userId = AuthManager.shared.currentUserId?.uuidString

        if let userId {
            do {
                let cached = try Message.fetchCached(
                    sessionId: sessionId,
                    userId: userId,
                    context: modelContext
                )
                if !cached.isEmpty {
                    messages = cached
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
}

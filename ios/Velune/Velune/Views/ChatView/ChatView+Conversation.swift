import SwiftData
import SwiftUI

extension ChatView {
    @MainActor
    func prepareConversation() async {
        messages = []
        inputText = ""
        errorMessage = nil
        hasScrolledToLatestOnAppear = false

        if isDraftSession {
            messages = []
        } else {
            await loadMessages()
        }

        if messages.isEmpty {
            await loadChapters()
        }
    }

    func dismissComposer() {
        isComposerFocused = false
    }

    @MainActor
    func sendMessage(prefilledContent: String? = nil) async {
        if isSending { return }

        let sourceContent = prefilledContent ?? inputText
        let content = sourceContent.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        shouldPauseAutoScrollDuringStreaming = false
        dismissComposer()
        inputText = ""
        defer {
            isSending = false
            shouldPauseAutoScrollDuringStreaming = false
        }

        let assistantLocalId = appendPendingMessages(for: content)

        do {
            var resolvedSessionId: UUID?
            var resolvedTitle: String?
            let startedFromDraft = isDraftSession
            for try await event in ChatStreamService.streamReply(
                sessionId: isDraftSession ? nil : activeSessionId,
                soulerId: soulerId,
                soulerName: soulerName,
                path: "api/v1/\(AppLanguage.current.apiLanguageCode)/chat",
                content: content
            ) {
                switch event {
                case let .delta(delta):
                    if let index = messages.firstIndex(where: { $0.id == assistantLocalId }) {
                        messages[index].content += delta
                    }
                case let .options(options):
                    if let index = messages.firstIndex(where: { $0.id == assistantLocalId }) {
                        let currentBody = chapterMessageBody(from: messages[index].content)
                        messages[index].content = chapterMessageStorageContent(
                            body: currentBody,
                            options: options
                        )
                    }
                case let .done(payload):
                    let result = applyDonePayload(payload)
                    resolvedSessionId = result.sessionId ?? resolvedSessionId
                    resolvedTitle = result.title ?? resolvedTitle
                }
            }
            try await finalizeSend(
                resolvedSessionId: resolvedSessionId,
                resolvedTitle: resolvedTitle,
                startedFromDraft: startedFromDraft
            )
        } catch {
            messages.removeAll { $0.id == assistantLocalId }
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    func appendPendingMessages(for content: String) -> UUID {
        messages.append(
            Message(
                id: UUID(),
                soulerId: soulerId,
                sessionId: isDraftSession ? nil : activeSessionId,
                role: .user,
                content: content,
                createdAt: .now
            )
        )

        let assistantLocalId = UUID()
        messages.append(
            Message(
                id: assistantLocalId,
                soulerId: soulerId,
                sessionId: isDraftSession ? nil : activeSessionId,
                role: .assistant,
                content: "",
                createdAt: .now
            )
        )
        return assistantLocalId
    }

    @MainActor
    func applyDonePayload(_ payload: ChatStreamService.DonePayload) -> (sessionId: UUID?, title: String?) {
        let title = payload.title?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            payload.sessionId,
            title.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    @MainActor
    func finalizeSend(
        resolvedSessionId: UUID?,
        resolvedTitle: String?,
        startedFromDraft: Bool
    ) async throws {
        if let resolvedSessionId {
            activeSessionId = resolvedSessionId
            isDraftSession = false
        }

        let sessionId = resolvedSessionId ?? activeSessionId
        let remoteMessages = try await Message.getHistory(sessionId: sessionId)
        messages = remoteMessages

        var authoritativeSession: ChatSession?
        if let fetchedSession = try? await ChatSession.get(id: sessionId) {
            authoritativeSession = fetchedSession
            mergeConversationSessionCacheIfPossible([fetchedSession])
        }

        cacheMessagesIfPossible(
            remoteMessages,
            sessionId: sessionId,
            fallbackSessionUpdatedAt: authoritativeSession?.updatedAt ?? Date.now
        )

        await loadConversationSessions()

        guard startedFromDraft, let resolvedSessionId, let onSelectSession else { return }

        let fallbackTitle = resolvedTitle ?? String(localized: "resonance.chat.newConversation")
        let routeSession = sessions.first(where: { $0.id == resolvedSessionId })
            ?? authoritativeSession
            ?? ChatSession(
                id: resolvedSessionId,
                soulerId: soulerId,
                chapterId: nil,
                soulerName: soulerName,
                title: fallbackTitle,
                updatedAt: .now
            )
        onSelectSession(routeSession)
    }

    @MainActor
    func openSession(_ session: ChatSession) {
        guard session.id != activeSessionId else { return }
        if let onSelectSession {
            onSelectSession(session)
            return
        }
        Task {
            await switchToExistingSession(session.id)
        }
    }

    @MainActor
    func startNewConversation() {
        if isDraftSession, messages.isEmpty {
            return
        }

        activeSessionId = UUID()
        isDraftSession = true
        messages = []
        inputText = ""
        errorMessage = nil
        hasScrolledToLatestOnAppear = false

        Task {
            await loadChapters()
        }
    }

    @MainActor
    func switchToExistingSession(_ sessionId: UUID) async {
        activeSessionId = sessionId
        isDraftSession = false
        await loadConversationSessions()
        await prepareConversation()
    }
}

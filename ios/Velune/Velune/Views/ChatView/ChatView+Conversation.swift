import SwiftData
import SwiftUI
import OSLog

extension ChatView {
    @MainActor
    func prepareConversation() async {
        messages = []
        inputText = ""
        chapterOptions = []
        errorMessage = nil
        billingErrorContext = nil
        hasScrolledToLatestOnAppear = false

        if isDraftSession {
            applyDraftPreludeIfNeeded()
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
    func loadMessages() async {
        if isDraftSession {
            messages = []
            return
        }
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await Message.getHistory(sessionId: activeSessionId)
        } catch {
            errorMessage = error.localizedDescription
            billingErrorContext = error.billingErrorContext
        }
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
        chapterOptions = []
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
                echoId: isDraftSession ? draftEchoId : nil,
                soulerId: soulerId,
                soulerName: soulerName,
                path: "\(AppLanguage.current.apiLanguageCode)/chat",
                content: content
            ) {
                switch event {
                case let .delta(delta):
                    if let index = messages.firstIndex(where: { $0.id == assistantLocalId }) {
                        messages[index].content += delta
                    }
                case let .options(options):
                    setChapterOptions(options)
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
            billingErrorContext = error.billingErrorContext
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
        let sourceDraftEchoId = draftEchoId

        if let resolvedSessionId {
            activeSessionId = resolvedSessionId
            isDraftSession = false
            draftEchoId = nil
            activeDraftPrelude = nil

            if let sourceDraftEchoId {
                persistEchoSessionIdIfNeeded(
                    echoId: sourceDraftEchoId,
                    sessionId: resolvedSessionId
                )
            }
        }

        let sessionId = resolvedSessionId ?? activeSessionId
        messages = try await Message.getHistory(sessionId: sessionId)
        await loadConversationSessions()

        guard startedFromDraft, let resolvedSessionId, let onSelectSession else { return }

        let fallbackTitle = resolvedTitle ?? String(localized: "resonance.chat.newConversation")
        let routeSession = sessions.first(where: { $0.id == resolvedSessionId }) ?? ChatSession(
            id: resolvedSessionId,
            soulerId: soulerId,
            chapterId: nil,
            soulerName: soulerName,
            title: fallbackTitle
        )
        onSelectSession(routeSession)
    }

    @MainActor
    func persistEchoSessionIdIfNeeded(echoId: UUID, sessionId: UUID) {
        var descriptor = FetchDescriptor<Echo>(
            predicate: #Predicate { echo in
                echo.id == echoId
            }
        )
        descriptor.fetchLimit = 1

        guard let echo = try? modelContext.fetch(descriptor).first else { return }
        guard echo.sessionId != sessionId else { return }

        echo.sessionId = sessionId
        do {
            try modelContext.save()
        } catch {
            logger.error("persisting echo sessionId failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    var selectedSessionId: UUID {
        activeSessionId
    }

    var conversationSessions: [ChatSession] {
        sessions
    }

    @MainActor
    func loadConversationSessions() async {
        if isLoadingSessions { return }
        isLoadingSessions = true
        defer { isLoadingSessions = false }

        do {
            sessions = try await ChatSession.getPage(soulerId: soulerId, limit: 20, offset: 0)
            sessionMenuError = nil
        } catch {
            sessionMenuError = error.localizedDescription
            sessions = []
        }
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
        draftEchoId = nil
        activeDraftPrelude = nil
        messages = []
        inputText = ""
        chapterOptions = []
        errorMessage = nil
        billingErrorContext = nil
        hasScrolledToLatestOnAppear = false

        Task {
            await loadChapters()
        }
    }

    @MainActor
    func applyDraftPreludeIfNeeded() {
        guard let activeDraftPrelude else { return }

        let trimmedGlimmer = activeDraftPrelude.glimmerContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEcho = activeDraftPrelude.echoContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedGlimmer.isEmpty {
            messages.append(
                Message(
                    id: UUID(),
                    soulerId: soulerId,
                    sessionId: nil,
                    role: .user,
                    content: trimmedGlimmer,
                    createdAt: .now
                )
            )
        }

        if !trimmedEcho.isEmpty {
            messages.append(
                Message(
                    id: UUID(),
                    soulerId: soulerId,
                    sessionId: nil,
                    role: .assistant,
                    content: trimmedEcho,
                    createdAt: .now
                )
            )
        }
    }

    @MainActor
    func switchToExistingSession(
        _ sessionId: UUID,
        initialOptions: [String] = []
    ) async {
        activeSessionId = sessionId
        isDraftSession = false
        draftEchoId = nil
        activeDraftPrelude = nil
        await prepareConversation()
        await loadConversationSessions()
        setChapterOptions(initialOptions)
    }
}

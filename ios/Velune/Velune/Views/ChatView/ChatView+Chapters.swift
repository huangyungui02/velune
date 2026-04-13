import SwiftUI
import OSLog

extension ChatView {
    @MainActor
    func loadChapters() async {
        if isLoadingChapters { return }

        isLoadingChapters = true
        defer { isLoadingChapters = false }

        do {
            chapters = try await SoulerChapter.fetchList(for: soulerId)
        } catch {
            logger.error("loading chapters failed: \(error.localizedDescription, privacy: .public)")
            chapters = []
        }
    }

    @MainActor
    func startChapterSession(_ chapter: SoulerChapter) async {
        if isStartingChapterSession { return }
        isStartingChapterSession = true
        defer { isStartingChapterSession = false }

        chapterOptions = []
        shouldPauseAutoScrollDuringStreaming = false
        let localAssistantId = UUID()
        messages = [
            Message(
                id: localAssistantId,
                soulerId: soulerId,
                sessionId: nil,
                role: .assistant,
                content: "…",
                createdAt: .now
            )
        ]

        do {
            let payload = try await ChapterSessionStartService.start(
                soulerId: soulerId,
                chapterId: chapter.id,
                path: chapterSessionStartPath(for: chapter.id)
            )

            let startedSession = ChatSession(
                id: payload.sessionId,
                soulerId: payload.soulerId,
                chapterId: payload.chapterId,
                soulerName: soulerName,
                title: payload.title
            )

            activeSessionId = payload.sessionId
            isDraftSession = false
            draftEchoId = nil
            activeDraftPrelude = nil

            if let messageIndex = messages.firstIndex(where: { $0.id == localAssistantId }) {
                messages[messageIndex].id = payload.assistantMessage.id
                messages[messageIndex].sessionId = payload.sessionId
                messages[messageIndex].createdAt = .now
                messages[messageIndex].content = ""
                await streamChapterOpeningContent(
                    payload.assistantMessage.content,
                    into: payload.assistantMessage.id
                )
            } else {
                messages = [
                    Message(
                        id: payload.assistantMessage.id,
                        soulerId: soulerId,
                        sessionId: payload.sessionId,
                        role: .assistant,
                        content: payload.assistantMessage.content,
                        createdAt: .now
                    )
                ]
            }

            setChapterOptions(payload.options)
            await loadConversationSessions()

            if let onSelectSession {
                onSelectSession(startedSession)
            }
        } catch {
            messages = []
            errorMessage = error.localizedDescription
            billingErrorContext = error.billingErrorContext
        }
    }

    @MainActor
    func streamChapterOpeningContent(_ content: String, into messageId: UUID) async {
        let text = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let characters = Array(text)
        let chunkSize = max(1, min(6, characters.count / 48))
        var index = 0

        while index < characters.count {
            let nextIndex = min(characters.count, index + chunkSize)
            let delta = String(characters[index ..< nextIndex])
            if let messageIndex = messages.firstIndex(where: { $0.id == messageId }) {
                messages[messageIndex].content += delta
            } else {
                break
            }

            index = nextIndex
            if index < characters.count {
                try? await Task.sleep(for: .milliseconds(16))
            }
        }
    }

    func chapterSessionStartPath(for chapterId: UUID) -> String {
        "\(AppLanguage.current.apiLanguageCode)/soulers/\(soulerId.uuidString)/chapters/\(chapterId.uuidString)/start"
    }

    func setChapterOptions(_ options: [String]?) {
        chapterOptions = normalizeChapterOptions(options ?? [])
    }

    func normalizeChapterOptions(_ options: [String]) -> [String] {
        Array(
            options
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(4)
        )
    }
}

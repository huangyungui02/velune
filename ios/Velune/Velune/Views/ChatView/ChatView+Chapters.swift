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

        shouldPauseAutoScrollDuringStreaming = false
        let localAssistantId = UUID()
        messages = [
            Message(
                id: localAssistantId,
                soulerId: soulerId,
                sessionId: nil,
                role: .assistant,
                content: "",
                createdAt: .now
            )
        ]

        do {
            let payload = try await ChapterSessionStartService.start(
                soulerId: soulerId,
                chapterId: chapter.id,
                path: chapterSessionStartPath(for: chapter.id)
            )
            let assistantCreatedAt = parseServerDate(payload.assistantMessage.createdAt) ?? .now
            let fullAssistantContent = payload.assistantMessage.content
            let openingBody = conversationMessageBody(from: fullAssistantContent)

            var startedSession = ChatSession(
                id: payload.sessionId,
                soulerId: payload.soulerId,
                chapterId: payload.chapterId,
                soulerName: soulerName,
                title: payload.title,
                updatedAt: .now
            )

            activeSessionId = payload.sessionId
            isDraftSession = false

            if let messageIndex = messages.firstIndex(where: { $0.id == localAssistantId }) {
                messages[messageIndex].id = payload.assistantMessage.id
                messages[messageIndex].sessionId = payload.sessionId
                messages[messageIndex].createdAt = assistantCreatedAt
                messages[messageIndex].content = ""
                await streamChapterOpeningContent(
                    openingBody,
                    into: payload.assistantMessage.id
                )
                messages[messageIndex].content = fullAssistantContent
            } else {
                messages = [
                    Message(
                        id: payload.assistantMessage.id,
                        soulerId: soulerId,
                        sessionId: payload.sessionId,
                        role: .assistant,
                        content: fullAssistantContent,
                        createdAt: assistantCreatedAt
                    )
                ]
            }

            if let fetchedSession = try? await ChatSession.get(id: payload.sessionId) {
                startedSession = fetchedSession
            }
            mergeConversationSessionCacheIfPossible([startedSession])
            cacheMessagesIfPossible(
                messages,
                sessionId: payload.sessionId,
                fallbackSessionUpdatedAt: startedSession.updatedAt
            )

            await loadConversationSessions()

            if let onSelectSession {
                onSelectSession(startedSession)
            }
        } catch {
            messages = []
            errorMessage = error.localizedDescription
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
        "v1/\(AppLanguage.current.apiLanguageCode)/soulers/\(soulerId.uuidString)/chapters/\(chapterId.uuidString)/start"
    }

    func normalizeChapterOptions(_ options: [String]) -> [String] {
        ConversationOptionParser.normalize(options)
    }

    func parseServerDate(_ value: String) -> Date? {
        let fractionalFormatter = ISO8601DateFormatter()
        fractionalFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalFormatter.date(from: value) {
            return date
        }

        let plainFormatter = ISO8601DateFormatter()
        plainFormatter.formatOptions = [.withInternetDateTime]
        return plainFormatter.date(from: value)
    }
}

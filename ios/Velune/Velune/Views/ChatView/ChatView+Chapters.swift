import SwiftUI
import OSLog

extension ChatView {
    @MainActor
    func loadChapterState(silent: Bool = false) async {
        if isLoadingChapters { return }
        if !silent {
            isLoadingChapters = true
        }
        defer {
            if !silent {
                isLoadingChapters = false
            }
        }

        do {
            let fetchedState = try await SoulerChapterState.fetch(for: soulerId)
            chapterState = reconcileChapterState(with: fetchedState)
            scheduleChapterPollingIfNeeded()
        } catch {
            logger.error("loading chapter state failed: \(error.localizedDescription, privacy: .public)")
            // Keep current visual state on transient read failures.
            chapterState = fallbackChapterStateAfterLoadFailure()
        }
    }

    @MainActor
    func scheduleChapterPollingIfNeeded() {
        cancelChapterPolling()

        guard chapterState?.status == .processing else { return }
        chapterPollingTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                await loadChapterState(silent: true)
                if chapterState?.status != .processing {
                    break
                }
            }
        }
    }

    @MainActor
    func generateChapters() async {
        if isTriggeringChapterGeneration { return }
        isTriggeringChapterGeneration = true
        defer { isTriggeringChapterGeneration = false }

        do {
            _ = try await ChapterGenerationService.generate(
                soulerId: soulerId,
                path: chapterGenerationPath
            )
            hasRequestedChapterGeneration = true
            chapterState = SoulerChapterState(
                status: .processing,
                chapters: chapterState?.chapters ?? []
            )
            scheduleChapterPollingIfNeeded()
        } catch {
            hasRequestedChapterGeneration = false
            errorMessage = error.localizedDescription
            billingErrorContext = error.billingErrorContext
        }
    }

    @MainActor
    func reconcileChapterState(with fetchedState: SoulerChapterState) -> SoulerChapterState {
        if fetchedState.status == .pending,
           hasRequestedChapterGeneration || chapterState?.status == .processing
        {
            let previousChapters = chapterState?.chapters ?? []
            return SoulerChapterState(
                status: .processing,
                chapters: previousChapters.isEmpty ? fetchedState.chapters : previousChapters
            )
        }

        if fetchedState.status != .pending {
            hasRequestedChapterGeneration = false
        }

        return fetchedState
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

    var chapterGenerationPath: String {
        "\(AppLanguage.current.apiLanguageCode)/soulers/\(soulerId.uuidString)/chapters/generate"
    }

    func chapterSessionStartPath(for chapterId: UUID) -> String {
        "\(AppLanguage.current.apiLanguageCode)/soulers/\(soulerId.uuidString)/chapters/\(chapterId.uuidString)/start"
    }

    @MainActor
    func cancelChapterPolling() {
        chapterPollingTask?.cancel()
        chapterPollingTask = nil
    }

    func fallbackChapterStateAfterLoadFailure() -> SoulerChapterState? {
        guard chapterState != nil || hasRequestedChapterGeneration else { return nil }
        return chapterState ?? SoulerChapterState(
            status: .processing,
            chapters: []
        )
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

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class StarSeaConversationSession {
    let openingText: String

    var threadId: String?
    var timelineEvents: [StarSeaTimelineEvent] = []
    var inputText = ""
    var isStreaming = false
    var isSettling = false
    var errorMessage: String?
    var hasStarted = false
    var currentAssistantMessageId: UUID?
    var shouldPauseAutoScrollDuringStreaming = false
    var settlementText = ""
    var settlementBlessing = ""
    var isAwaitingSettlementConfirmation = false
    var isShowingImmersiveSettlement = false
    var isSettlementReady = false
    var isLeaving = false

    @ObservationIgnored
    private var activeTask: Task<Void, Never>?

    var canSendMessage: Bool {
        !isStreaming
            && !isSettling
            && !isAwaitingSettlementConfirmation
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && threadId != nil
    }

    var shouldLeaveDirectly: Bool {
        isAwaitingSettlementConfirmation || threadId == nil
    }

    init(openingText: String) {
        self.openingText = openingText
    }

    func startIfNeeded() async {
        guard !hasStarted else { return }
        hasStarted = true
        await startOpeningTurn()
    }

    func sendFollowUp() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, threadId != nil, !isAwaitingSettlementConfirmation else { return }

        inputText = ""
        timelineEvents.append(.message(StarSeaMessage(role: .user, content: content)))
        await streamTurn(content: content)
    }

    func selectConversationOption(_ option: String) {
        inputText = option
    }

    func showImmersiveSettlement() {
        withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
            isShowingImmersiveSettlement = true
        }
    }

    func settleAndLeave() async {
        guard let threadId, !isSettling else { return }

        isSettling = true
        errorMessage = nil
        settlementText = ""
        settlementBlessing = ""
        isSettlementReady = false
        isAwaitingSettlementConfirmation = true
        showImmersiveSettlement()
        cancelActiveTask()

        do {
            for try await event in StarSeaStreamService.stream(
                threadId: threadId,
                content: nil,
                intent: .collect
            ) {
                handleSettlementEvent(event)
            }
            if !isSettlementReady {
                errorMessage = String(localized: "starsea.leave.settleFailed")
                isAwaitingSettlementConfirmation = false
                withAnimation {
                    isShowingImmersiveSettlement = false
                }
            }
        } catch {
            errorMessage = error.localizedDescription
            isAwaitingSettlementConfirmation = false
            withAnimation {
                isShowingImmersiveSettlement = false
            }
        }

        isSettling = false
    }

    func cancelActiveTask() {
        activeTask?.cancel()
        activeTask = nil
    }

    func prepareDirectLeave() {
        guard !isLeaving else { return }
        isLeaving = true
        cancelActiveTask()
        isShowingImmersiveSettlement = false
    }

    private func startOpeningTurn() async {
        let content = openingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        timelineEvents.append(.message(StarSeaMessage(role: .user, content: content)))
        await streamTurn(content: content)
    }

    private func streamTurn(content: String) async {
        guard !isStreaming, !isAwaitingSettlementConfirmation else { return }

        isStreaming = true
        shouldPauseAutoScrollDuringStreaming = false
        errorMessage = nil
        let placeholderMessage = StarSeaMessage(role: .assistant, content: "")
        currentAssistantMessageId = placeholderMessage.id
        timelineEvents.append(.message(placeholderMessage))

        cancelActiveTask()
        activeTask = Task { [weak self] in
            guard let self else { return }

            do {
                for try await event in StarSeaStreamService.stream(
                    threadId: threadId,
                    content: content
                ) {
                    handle(event)
                }
            } catch {
                showStreamFailure(error.localizedDescription)
            }

            isStreaming = false
            shouldPauseAutoScrollDuringStreaming = false
            activeTask = nil
        }

        await activeTask?.value
    }

    private func handle(_ event: StarSeaStreamService.Event) {
        switch event {
        case let .ready(threadId):
            self.threadId = threadId
        case let .delta(delta):
            appendAssistant(delta: delta)
        case let .options(options):
            appendConversationOptions(options)
        case let .resonanceMatch(matches):
            appendResonanceMatches(matches)
        case let .done(threadId):
            if let threadId {
                self.threadId = threadId
            }
        case let .settled(glimmer):
            removeEmptyAssistantMessage(id: currentAssistantMessageId)
            currentAssistantMessageId = nil
            settlementText = glimmer.content
            settlementBlessing = (glimmer.blessing ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            isSettlementReady = true
            isAwaitingSettlementConfirmation = true
            showImmersiveSettlement()
        }
    }

    private func handleSettlementEvent(_ event: StarSeaStreamService.Event) {
        switch event {
        case let .ready(threadId):
            self.threadId = threadId
        case let .delta(delta):
            settlementText += delta
        case let .settled(glimmer):
            settlementText = glimmer.content
            settlementBlessing = (glimmer.blessing ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            isSettlementReady = true
        case .options, .resonanceMatch, .done:
            break
        }
    }

    private func appendAssistant(delta: String) {
        if let messageId = currentAssistantMessageId,
           let index = timelineEvents.firstMessageIndex(id: messageId) {
            timelineEvents[index].appendMessageContent(delta)
            return
        }

        let message = StarSeaMessage(role: .assistant, content: delta)
        currentAssistantMessageId = message.id
        timelineEvents.append(.message(message))
    }

    private func appendConversationOptions(_ options: [String]) {
        let targetMessageId = currentAssistantMessageId ?? timelineEvents.lastAssistantMessageId
        guard let targetMessageId,
              let index = timelineEvents.firstMessageIndex(id: targetMessageId)
        else {
            return
        }

        let currentContent = timelineEvents[index].message?.content ?? ""
        let body = ConversationOptionParser.parse(currentContent).body
        timelineEvents[index].replaceMessageContent(
            ConversationOptionParser.storageContent(body: body, options: options)
        )
    }

    private func appendResonanceMatches(_ matches: [StarSeaStreamService.ResonanceMatch]) {
        removeEmptyAssistantMessage(id: currentAssistantMessageId)
        currentAssistantMessageId = nil

        guard !matches.isEmpty else { return }
        timelineEvents.append(.resonanceMatches(id: UUID(), matches: matches))
    }

    private func removeEmptyAssistantMessage(id: UUID?) {
        guard let id else { return }
        timelineEvents.removeAll { event in
            guard case let .message(message) = event else { return false }
            return message.id == id && message.content.isEmpty
        }
    }

    private func showStreamFailure(_ message: String) {
        if let messageId = currentAssistantMessageId,
           let index = timelineEvents.firstMessageIndex(id: messageId) {
            timelineEvents[index].replaceMessageContent(message)
        } else {
            timelineEvents.append(.message(StarSeaMessage(role: .assistant, content: message)))
        }
        errorMessage = message
    }
}

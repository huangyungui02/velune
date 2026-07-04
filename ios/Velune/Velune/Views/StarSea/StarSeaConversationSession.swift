import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class StarSeaConversationSession {
    let openingText: String
    let divinationData: DivinationData?
    
    var threadId: String?
    var timelineEvents: [StarSeaTimelineEvent] = []
    var inputText = ""
    var isStreaming = false
    var isSettling = false
    var errorMessage: String?
    var hasStarted = false
    var currentAssistantMessageId: UUID?
    var currentThinkingMessageId: UUID?
    var currentThinkingStartedAt: Date?
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

    init(openingText: String, divinationData: DivinationData? = nil) {
        self.openingText = openingText
        self.divinationData = divinationData
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
        await streamTurn(content: .text(content))
    }

    func startDivination(question: String, divinationData: DivinationData) async {
        let content = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, !hasStarted else { return }

        hasStarted = true
        inputText = ""
        timelineEvents.append(.divinationResult(id: UUID(), divination: divinationData))
        timelineEvents.append(.message(StarSeaMessage(role: .user, content: content)))
        await streamTurn(content: divinationData.streamContent(question: content))
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
                content: .triggerCollect
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

        if let divinationData {
            timelineEvents.append(.divinationResult(id: UUID(), divination: divinationData))
        }

        timelineEvents.append(.message(StarSeaMessage(role: .user, content: content)))
        
        let requestContent: StarSeaStreamService.Content
        if let divinationData {
            requestContent = divinationData.streamContent(question: content)
        } else {
            requestContent = .text(content)
        }
        
        await streamTurn(content: requestContent)
    }
    
    private func streamTurn(content: StarSeaStreamService.Content) async {
        guard !isStreaming, !isAwaitingSettlementConfirmation else { return }

        isStreaming = true
        shouldPauseAutoScrollDuringStreaming = false
        errorMessage = nil
        currentAssistantMessageId = nil
        currentThinkingMessageId = nil
        currentThinkingStartedAt = nil

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
        case let .delta(delta, displayType):
            appendDelta(delta, displayType: displayType)
        case let .options(options):
            appendConversationOptions(options)
        case let .resonanceMatch(matches):
            appendResonanceMatches(matches)
        case let .done(threadId):
            if let threadId {
                self.threadId = threadId
            }
            finishThinkingIfNeeded()
        case let .settled(glimmer):
            removeEmptyAssistantMessage(id: currentAssistantMessageId)
            currentAssistantMessageId = nil
            finishThinkingIfNeeded()
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
        case let .delta(delta, _):
            settlementText += delta
        case let .settled(glimmer):
            settlementText = glimmer.content
            settlementBlessing = (glimmer.blessing ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            isSettlementReady = true
        case .options, .resonanceMatch, .done:
            break
        }
    }

    private func appendDelta(_ delta: String, displayType: StarSeaStreamService.DeltaDisplayType) {
        if displayType == .thinking {
            appendThinking(delta: delta)
            return
        }

        appendAssistant(delta: delta)
    }

    private func appendAssistant(delta: String) {
        finishThinkingIfNeeded()

        if let messageId = currentAssistantMessageId,
           let index = timelineEvents.firstMessageIndex(id: messageId) {
            timelineEvents[index].appendMessageContent(delta)
            return
        }

        let message = StarSeaMessage(role: .assistant, content: delta)
        currentAssistantMessageId = message.id
        timelineEvents.append(.message(message))
    }

    private func appendThinking(delta: String) {
        if let messageId = currentThinkingMessageId,
           let index = timelineEvents.firstMessageIndex(id: messageId) {
            timelineEvents[index].appendMessageContent(delta)
            return
        }

        let message = StarSeaMessage(role: .assistant, displayType: .thinking, content: delta)
        currentThinkingMessageId = message.id
        currentThinkingStartedAt = Date()
        timelineEvents.append(.message(message))
    }

    private func finishThinkingIfNeeded() {
        guard let messageId = currentThinkingMessageId,
              let index = timelineEvents.firstMessageIndex(id: messageId)
        else {
            currentThinkingStartedAt = nil
            return
        }

        let duration = currentThinkingStartedAt.map {
            max(1, Int(Date().timeIntervalSince($0).rounded(.up)))
        } ?? 1

        timelineEvents[index].finishThinking(durationSeconds: duration)
        currentThinkingMessageId = nil
        currentThinkingStartedAt = nil
    }

    private func appendConversationOptions(_ options: [String]) {
        let targetMessageId = currentAssistantMessageId ?? timelineEvents.lastStarseaAssistantMessageId
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
        finishThinkingIfNeeded()

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
        finishThinkingIfNeeded()

        if let messageId = currentAssistantMessageId,
           let index = timelineEvents.firstMessageIndex(id: messageId) {
            timelineEvents[index].replaceMessageContent(message)
        } else {
            timelineEvents.append(.message(StarSeaMessage(role: .assistant, content: message)))
        }
        errorMessage = message
    }
}

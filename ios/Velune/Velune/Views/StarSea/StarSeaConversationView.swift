import SwiftUI

struct StarSeaConversationView: View {
    let openingText: String
    let onLeave: () -> Void

    @State private var threadId: String?
    @State private var timelineEvents: [StarSeaTimelineEvent] = []
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var isSettling = false
    @State private var errorMessage: String?
    @State private var hasStarted = false
    @State private var currentAssistantMessageId: UUID?
    @State private var shouldPauseAutoScrollDuringStreaming = false
    @State private var activeTask: Task<Void, Never>?
    @State private var isLeaveConfirmationPresented = false
    @State private var settlementText = ""
    @State private var isAwaitingSettlementConfirmation = false
    @State private var isShowingImmersiveSettlement = false
    @State private var isSettlementReady = false
    @State private var pulseScale: CGFloat = 1.0
    @State private var isLeaving = false
    @FocusState private var isComposerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StarryBackgroundView()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                messageList
                if isAwaitingSettlementConfirmation && !isShowingImmersiveSettlement {
                    glimmerAccessoryView
                } else if !isShowingImmersiveSettlement {
                    composer
                }
            }
            .opacity(isShowingImmersiveSettlement ? 0 : 1)
            .blur(radius: isShowingImmersiveSettlement ? 12 : 0)
            .animation(.easeInOut(duration: 0.8), value: isShowingImmersiveSettlement)

            if isShowingImmersiveSettlement {
                ImmersiveSettlementView(
                    text: settlementText,
                    isGenerating: isSettling,
                    isReady: isSettlementReady,
                    onExit: requestLeave
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .overlay(alignment: .leading) {
            Color.clear
                .frame(width: 28)
                .contentShape(.rect)
                .gesture(backSwipeGesture)
        }
        .navigationBarBackButtonHidden(true)
        .navigationTitle("app.tab.starsea")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isShowingImmersiveSettlement ? .hidden : .visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: requestLeave) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                }
                .accessibilityLabel(Text("common.back"))
            }
        }
        .confirmationDialog(
            leaveConfirmationTitle,
            isPresented: $isLeaveConfirmationPresented,
            titleVisibility: .visible
        ) {
            if !isAwaitingSettlementConfirmation {
                Button("starsea.leave.settle") {
                    Task { await settleAndLeave() }
                }
                .disabled(threadId == nil || isSettling)

                Button("starsea.leave.direct", role: .destructive) {
                    leaveDirectly()
                }
            }

            Button("common.cancel", role: .cancel) {}
        } message: {
            Text(leaveConfirmationMessage)
        }
        .alert("matching.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "matching.error.unknown"))
        }
        .task {
            guard !hasStarted else { return }
            hasStarted = true
            await startOpeningTurn()
        }
        .onDisappear {
            activeTask?.cancel()
            activeTask = nil
        }
    }

    private var messageList: some View {
        StarSeaConversationMessageList(
            events: timelineEvents,
            isOptionsDisabled: isStreaming || isSettling || threadId == nil,
            isStreaming: isStreaming,
            shouldPauseAutoScrollDuringStreaming: $shouldPauseAutoScrollDuringStreaming,
            showsOptions: !isAwaitingSettlementConfirmation,
            onDismissComposerFocus: { isComposerFocused = false },
            onSelectOption: selectConversationOption
        )
    }

    private var composer: some View {
        SereneChatComposer(
            text: $inputText,
            isFocused: $isComposerFocused,
            isBusy: isStreaming || isSettling,
            canSend: canSendMessage,
            placeholderKey: "starsea.chat.placeholder"
        ) {
            await sendFollowUp()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private var glimmerAccessoryView: some View {
        Button(action: {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                isShowingImmersiveSettlement = true
            }
        }) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 44, height: 44)
                        .scaleEffect(pulseScale)
                        .animation(
                            .easeInOut(duration: 2.0).repeatForever(autoreverses: true),
                            value: pulseScale
                        )

                    Circle()
                        .stroke(
                            LinearGradient(
                                colors: [.white.opacity(0.3), .white.opacity(0.05), .white.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                        .frame(width: 36, height: 36)

                    Image(systemName: "sparkles")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color(red: 0.85, green: 0.9, blue: 1.0), Color(red: 0.6, green: 0.75, blue: 1.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("starsea.settlement.readyTitle")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)

                    Text("starsea.settlement.clickToView")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.trailing, 4)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color(red: 0.05, green: 0.06, blue: 0.09).opacity(0.55))
            )
            .glassEffect(in: .rect(cornerRadius: 22))
            .overlay {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.12), .white.opacity(0.04), .white.opacity(0.12)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 0.6
                    )
            }
            .shadow(color: Color.black.opacity(0.25), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
        .onAppear {
            pulseScale = 1.15
        }
    }

    private var canSendMessage: Bool {
        !isStreaming
            && !isSettling
            && !isAwaitingSettlementConfirmation
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && threadId != nil
    }

    private var leaveConfirmationTitle: LocalizedStringKey {
        "starsea.leave.title"
    }

    private var leaveConfirmationMessage: LocalizedStringKey {
        "starsea.leave.message"
    }

    private var backSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                guard !isShowingImmersiveSettlement else { return }
                guard value.startLocation.x < 24, value.translation.width > 60 else { return }
                requestLeave()
            }
    }

    private func startOpeningTurn() async {
        let content = openingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        timelineEvents.append(.message(StarSeaMessage(role: .user, content: content)))
        await streamTurn(content: content)
    }

    private func sendFollowUp() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, threadId != nil, !isAwaitingSettlementConfirmation else { return }

        inputText = ""
        timelineEvents.append(.message(StarSeaMessage(role: .user, content: content)))
        await streamTurn(content: content)
    }

    private func selectConversationOption(_ option: String) {
        inputText = option
        isComposerFocused = true
    }

    private func streamTurn(content: String) async {
        guard !isStreaming, !isAwaitingSettlementConfirmation else { return }

        isStreaming = true
        shouldPauseAutoScrollDuringStreaming = false
        errorMessage = nil
        currentAssistantMessageId = nil

        activeTask?.cancel()
        activeTask = Task {
            do {
                for try await event in StarSeaStreamService.stream(
                    threadId: threadId,
                    content: content
                ) {
                    await MainActor.run {
                        handle(event)
                    }
                }
            } catch {
                await MainActor.run {
                    showStreamFailure(error.localizedDescription)
                }
            }

            await MainActor.run {
                isStreaming = false
                shouldPauseAutoScrollDuringStreaming = false
                activeTask = nil
            }
        }

        await activeTask?.value
    }

    private func settleAndLeave() async {
        guard let threadId, !isSettling else { return }

        isSettling = true
        errorMessage = nil
        settlementText = ""
        isSettlementReady = false
        isAwaitingSettlementConfirmation = true
        withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
            isShowingImmersiveSettlement = true
        }
        isComposerFocused = false
        activeTask?.cancel()

        do {
            for try await event in StarSeaStreamService.stream(
                threadId: threadId,
                content: nil,
                intent: .collect
            ) {
                await MainActor.run {
                    handleSettlementEvent(event)
                }
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
            isSettlementReady = true
            isAwaitingSettlementConfirmation = true
            withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                isShowingImmersiveSettlement = true
            }
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

    private func requestLeave() {
        if isAwaitingSettlementConfirmation {
            leaveDirectly()
            return
        }

        guard threadId != nil else {
            leaveDirectly()
            return
        }

        isLeaveConfirmationPresented = true
    }

    private func leaveDirectly() {
        guard !isLeaving else { return }
        isLeaving = true
        activeTask?.cancel()
        activeTask = nil
        isComposerFocused = false
        isLeaveConfirmationPresented = false
        isShowingImmersiveSettlement = false

        Task { @MainActor in
            await Task.yield()
            onLeave()
        }
    }
}

private extension [StarSeaTimelineEvent] {
    func firstMessageIndex(id: UUID) -> Index? {
        firstIndex { event in
            guard case let .message(message) = event else { return false }
            return message.id == id
        }
    }

    var lastAssistantMessageId: UUID? {
        reversed().compactMap(\.message).first { $0.role == .assistant }?.id
    }
}

private extension StarSeaTimelineEvent {
    mutating func appendMessageContent(_ content: String) {
        guard case var .message(message) = self else { return }
        message.content += content
        self = .message(message)
    }

    mutating func replaceMessageContent(_ content: String) {
        guard case var .message(message) = self else { return }
        message.content = content
        self = .message(message)
    }
}

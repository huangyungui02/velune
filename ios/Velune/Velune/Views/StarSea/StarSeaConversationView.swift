import SwiftUI

struct StarSeaConversationView: View {
    let onBlessing: (String) -> Void
    let onLeave: () -> Void

    @State private var session: StarSeaConversationSession
    @State private var isPreparingDivination: Bool
    @State private var divinationData = DivinationData(castedLines: [], date: Date())
    @State private var isDivinationFinished = false
    @State private var visibleDivinationLinesCount = 0
    @State private var showsDivinationComposer = false
    @FocusState private var isComposerFocused: Bool

    init(
        openingText: String,
        divinationData: DivinationData? = nil,
        onBlessing: @escaping (String) -> Void = { _ in },
        onLeave: @escaping () -> Void
    ) {
        self.onBlessing = onBlessing
        self.onLeave = onLeave
        _session = State(initialValue: StarSeaConversationSession(openingText: openingText, divinationData: divinationData))
        _isPreparingDivination = State(initialValue: false)
    }

    init(
        startsWithDivination: Bool,
        onBlessing: @escaping (String) -> Void = { _ in },
        onLeave: @escaping () -> Void
    ) {
        self.onBlessing = onBlessing
        self.onLeave = onLeave
        _session = State(initialValue: StarSeaConversationSession(openingText: ""))
        _isPreparingDivination = State(initialValue: startsWithDivination)
    }

    var body: some View {
        ZStack {
            StarryBackgroundView()
                .ignoresSafeArea()

            conversationSurface

            if session.isShowingImmersiveSettlement {
                ImmersiveSettlementView(
                    text: session.settlementText,
                    isGenerating: session.isSettling,
                    isReady: session.isSettlementReady,
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
        .navigationTitle("starsea.chat.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(session.isShowingImmersiveSettlement ? .hidden : .visible, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: requestLeave) {
                    Image(systemName: "chevron.left")
                        .font(.body.weight(.medium))
                }
                .accessibilityLabel(Text("common.back"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                if isPreparingDivination && (isDivinationFinished || !divinationData.castedLines.isEmpty) {
                    Button(action: recastDivination) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.body.weight(.medium))
                    }
                    .accessibilityLabel(Text("divination.result.recast"))
                }
            }
        }
        .alert("matching.error.title", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(session.errorMessage ?? String(localized: "matching.error.unknown"))
        }
        .task {
            guard !isPreparingDivination else { return }
            await session.startIfNeeded()
        }
        .onChange(of: session.settlementBlessing) { _, blessing in
            let normalized = blessing.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !normalized.isEmpty else { return }
            onBlessing(normalized)
        }
    }

    private var conversationSurface: some View {
        VStack(spacing: 0) {
            if isPreparingDivination {
                divinationSurface
            } else {
                messageList
            }

            if !session.isShowingImmersiveSettlement && (!isPreparingDivination || showsDivinationComposer) {
                composer
            }
        }
        .opacity(session.isShowingImmersiveSettlement ? 0 : 1)
        .blur(radius: session.isShowingImmersiveSettlement ? 12 : 0)
        .animation(.easeInOut(duration: 0.8), value: session.isShowingImmersiveSettlement)
    }

    private var messageList: some View {
        StarSeaConversationMessageList(
            events: session.timelineEvents,
            isOptionsDisabled: session.isStreaming || session.isSettling || session.threadId == nil,
            isStreaming: session.isStreaming,
            shouldPauseAutoScrollDuringStreaming: $session.shouldPauseAutoScrollDuringStreaming,
            showsOptions: !session.isAwaitingSettlementConfirmation,
            onDismissComposerFocus: { isComposerFocused = false },
            onSelectOption: selectConversationOption
        )
    }

    private var divinationSurface: some View {
        DivinationView(
            divinationData: $divinationData,
            isFinished: $isDivinationFinished,
            visibleLinesCount: $visibleDivinationLinesCount,
            showTexts: $showsDivinationComposer
        )
        .contentShape(.rect)
        .onTapGesture {
            isComposerFocused = false
        }
    }

    private var composer: some View {
        SereneChatComposer(
            text: $session.inputText,
            isFocused: $isComposerFocused,
            isBusy: session.isStreaming || session.isSettling,
            canSend: canSendComposer,
            placeholderKey: composerPlaceholderKey
        ) {
            isComposerFocused = false
            if isPreparingDivination {
                await startDivinationInterpretation()
            } else {
                await session.sendFollowUp()
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private var backSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                guard !session.isShowingImmersiveSettlement else { return }
                guard value.startLocation.x < 24, value.translation.width > 60 else { return }
                requestLeave()
            }
    }

    private var canSendComposer: Bool {
        if isPreparingDivination {
            return isDivinationFinished
                && showsDivinationComposer
                && divinationData.castedLines.count == 6
                && !session.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        return session.canSendMessage
    }

    private var composerPlaceholderKey: LocalizedStringKey {
        isPreparingDivination ? "divination.input.placeholder" : "starsea.chat.placeholder"
    }

    private func selectConversationOption(_ option: String) {
        session.selectConversationOption(option)
        isComposerFocused = true
    }

    private func requestLeave() {
        if isPreparingDivination {
            leaveDirectly()
            return
        }

        if session.shouldLeaveDirectly {
            leaveDirectly()
            return
        }

        isComposerFocused = false
        Task { await session.settleAndLeave() }
    }

    private func leaveDirectly() {
        guard !session.isLeaving else { return }
        session.prepareDirectLeave()
        isComposerFocused = false

        Task { @MainActor in
            await Task.yield()
            onLeave()
        }
    }

    private func startDivinationInterpretation() async {
        let question = session.inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isDivinationFinished, divinationData.castedLines.count == 6, !question.isEmpty else { return }

        withAnimation(.easeInOut(duration: 0.24)) {
            isPreparingDivination = false
        }
        await session.startDivination(question: question, divinationData: divinationData)
    }

    private func recastDivination() {
        withAnimation(.easeInOut(duration: 0.4)) {
            divinationData = DivinationData(castedLines: [], date: Date())
            isDivinationFinished = false
            visibleDivinationLinesCount = 0
            showsDivinationComposer = false
            session.inputText = ""
        }
    }
}

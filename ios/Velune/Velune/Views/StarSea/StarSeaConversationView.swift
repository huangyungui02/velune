import SwiftUI

struct StarSeaConversationView: View {
    let onBlessing: (String) -> Void
    let onLeave: () -> Void

    @State private var session: StarSeaConversationSession
    @FocusState private var isComposerFocused: Bool

    init(
        openingText: String,
        onBlessing: @escaping (String) -> Void = { _ in },
        onLeave: @escaping () -> Void
    ) {
        self.onBlessing = onBlessing
        self.onLeave = onLeave
        _session = State(initialValue: StarSeaConversationSession(openingText: openingText))
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
        .alert("matching.error.title", isPresented: Binding(
            get: { session.errorMessage != nil },
            set: { if !$0 { session.errorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(session.errorMessage ?? String(localized: "matching.error.unknown"))
        }
        .task {
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
            messageList

            if !session.isShowingImmersiveSettlement {
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

    private var composer: some View {
        SereneChatComposer(
            text: $session.inputText,
            isFocused: $isComposerFocused,
            isBusy: session.isStreaming || session.isSettling,
            canSend: session.canSendMessage,
            placeholderKey: "starsea.chat.placeholder"
        ) {
            isComposerFocused = false
            await session.sendFollowUp()
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

    private func selectConversationOption(_ option: String) {
        session.selectConversationOption(option)
        isComposerFocused = true
    }

    private func requestLeave() {
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
}

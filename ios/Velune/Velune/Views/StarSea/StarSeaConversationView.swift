import SwiftUI

struct StarSeaConversationView: View {
    let onLeave: () -> Void

    @State private var session: StarSeaConversationSession
    @FocusState private var isComposerFocused: Bool

    init(openingText: String, onLeave: @escaping () -> Void) {
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
        .navigationTitle("app.tab.starsea")
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
        .confirmationDialog(
            leaveConfirmationTitle,
            isPresented: $session.isLeaveConfirmationPresented,
            titleVisibility: .visible
        ) {
            if !session.isAwaitingSettlementConfirmation {
                Button("starsea.leave.settle") {
                    isComposerFocused = false
                    Task { await session.settleAndLeave() }
                }
                .disabled(session.threadId == nil || session.isSettling)

                Button("starsea.leave.direct", role: .destructive) {
                    leaveDirectly()
                }
            }
        } message: {
            Text(leaveConfirmationMessage)
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
            await session.sendFollowUp()
        }
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
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

        session.isLeaveConfirmationPresented = true
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

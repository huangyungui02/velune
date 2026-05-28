import SwiftUI

struct StarSeaConversationView: View {
    let openingText: String
    let onLeave: () -> Void

    @State private var threadId: String?
    @State private var messages: [StarSeaMessage] = []
    @State private var inputText = ""
    @State private var isStreaming = false
    @State private var isSettling = false
    @State private var errorMessage: String?
    @State private var hasStarted = false
    @State private var resonanceMatches: [StarSeaStreamService.ResonanceMatch] = []
    @State private var shouldPauseAutoScrollDuringStreaming = false
    @State private var activeTask: Task<Void, Never>?
    @State private var isLeaveConfirmationPresented = false
    @State private var settlementText = ""
    @State private var isAwaitingSettlementConfirmation = false
    @State private var isSettlementSheetPresented = false
    @State private var isEditingSettlement = false
    @State private var settlementSheetDetent = PresentationDetent.medium
    @State private var isSavingSettlement = false
    @State private var isLeaving = false
    @FocusState private var isComposerFocused: Bool
    @FocusState private var isSettlementEditorFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StarryBackgroundView()

            VStack(spacing: 0) {
                messageList
                if !isAwaitingSettlementConfirmation {
                    composer
                }
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
            if isAwaitingSettlementConfirmation {
                Button("starsea.settlement.discardConfirm", role: .destructive) {
                    Task { await discardSettlement() }
                }
            } else {
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
        .sheet(isPresented: $isSettlementSheetPresented) {
            StarSeaSettlementSheet(
                text: $settlementText,
                isEditing: $isEditingSettlement,
                isSaving: isSavingSettlement,
                isEditorFocused: $isSettlementEditorFocused,
                onExit: requestLeave,
                onEdit: openSettlementEditor,
                onSave: saveSettlement
            )
            .interactiveDismissDisabled()
            .presentationDetents([.medium, .large], selection: $settlementSheetDetent)
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .onChange(of: settlementSheetDetent) { _, detent in
            guard detent != .large, isEditingSettlement else { return }
            isEditingSettlement = false
            isSettlementEditorFocused = false
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
            messages: messages,
            resonanceMatches: resonanceMatches,
            isOptionsDisabled: isStreaming || isSettling || threadId == nil,
            isStreaming: isStreaming,
            shouldPauseAutoScrollDuringStreaming: $shouldPauseAutoScrollDuringStreaming,
            showsOptions: !isAwaitingSettlementConfirmation,
            onDismissComposerFocus: { isComposerFocused = false },
            onSelectOption: selectConversationOption
        )
    }

    private var composer: some View {
        StarSeaConversationComposer(
            text: $inputText,
            isFocused: $isComposerFocused,
            isBusy: isStreaming || isSettling,
            canSend: canSendMessage,
            reduceMotion: reduceMotion,
            onSend: sendFollowUp
        )
    }

    private var canSendMessage: Bool {
        !isStreaming
            && !isSettling
            && !isAwaitingSettlementConfirmation
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && threadId != nil
    }

    private var leaveConfirmationTitle: LocalizedStringKey {
        isAwaitingSettlementConfirmation ? "starsea.settlement.exit.title" : "starsea.leave.title"
    }

    private var leaveConfirmationMessage: LocalizedStringKey {
        isAwaitingSettlementConfirmation ? "starsea.settlement.exit.message" : "starsea.leave.message"
    }

    private var backSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 24, coordinateSpace: .local)
            .onEnded { value in
                guard value.startLocation.x < 24, value.translation.width > 60 else { return }
                requestLeave()
            }
    }

    private func startOpeningTurn() async {
        let content = openingText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        messages.append(StarSeaMessage(role: .user, content: content))
        await streamTurn(content: content)
    }

    private func sendFollowUp() async {
        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty, threadId != nil, !isAwaitingSettlementConfirmation else { return }

        inputText = ""
        resonanceMatches = []
        messages.append(StarSeaMessage(role: .user, content: content))
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
        messages.append(StarSeaMessage(role: .assistant, content: ""))
        let assistantId = messages.last?.id

        activeTask?.cancel()
        activeTask = Task {
            do {
                for try await event in StarSeaStreamService.stream(
                    threadId: threadId,
                    content: content
                ) {
                    await MainActor.run {
                        handle(event, assistantId: assistantId)
                    }
                }
            } catch {
                await MainActor.run {
                    showStreamFailure(error.localizedDescription, assistantId: assistantId)
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
        activeTask?.cancel()

        do {
            for try await event in StarSeaStreamService.stream(
                threadId: threadId,
                content: nil,
                intent: .collect
            ) {
                if case let .confirmRequired(threadId, content) = event {
                    presentSettlement(threadId: threadId, content: content)
                    return
                }
            }
            errorMessage = String(localized: "starsea.leave.settleFailed")
        } catch {
            errorMessage = error.localizedDescription
        }

        isSettling = false
    }

    private func handle(_ event: StarSeaStreamService.Event, assistantId: UUID?) {
        switch event {
        case let .ready(threadId):
            self.threadId = threadId
        case let .delta(delta):
            append(delta: delta, to: assistantId)
        case let .resonanceMatch(matches):
            resonanceMatches = matches
        case let .confirmRequired(threadId, content):
            presentSettlement(threadId: threadId, content: content)
        case let .done(threadId):
            if let threadId {
                self.threadId = threadId
            }
        case let .settled(glimmer):
            removeEmptyAssistantMessage(id: assistantId)
            settlementText = glimmer.content
            leaveDirectly()
        case .discarded:
            leaveDirectly()
        }
    }

    private func presentSettlement(threadId: String, content: String) {
        self.threadId = threadId
        settlementText = content
        isAwaitingSettlementConfirmation = true
        isEditingSettlement = false
        isSettlementSheetPresented = true
        settlementSheetDetent = .medium
        isSavingSettlement = false
        isSettling = false
        isComposerFocused = false
    }

    private func openSettlementEditor() {
        guard !isSavingSettlement else { return }
        isEditingSettlement = true
        settlementSheetDetent = .large
        Task { @MainActor in
            await Task.yield()
            isSettlementEditorFocused = true
        }
    }

    private func saveSettlement() {
        Task { await saveSettlementAsync() }
    }

    private func saveSettlementAsync() async {
        guard let threadId, !isSavingSettlement else { return }

        let content = settlementText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSavingSettlement = true
        errorMessage = nil

        do {
            for try await event in StarSeaStreamService.resume(
                threadId: threadId,
                approved: true,
                content: content
            ) {
                if case .settled = event {
                    leaveDirectly()
                    return
                }
            }
            errorMessage = String(localized: "starsea.leave.settleFailed")
            isSavingSettlement = false
        } catch {
            errorMessage = error.localizedDescription
            isSavingSettlement = false
        }
    }

    private func discardSettlement() async {
        let threadId = threadId
        leaveDirectly()

        guard let threadId else { return }
        Task {
            do {
                for try await _ in StarSeaStreamService.resume(
                    threadId: threadId,
                    approved: false,
                    content: nil
                ) {}
            } catch {}
        }
    }

    private func append(delta: String, to messageId: UUID?) {
        guard let messageId, let index = messages.firstIndex(where: { $0.id == messageId }) else { return }
        messages[index].content += delta
    }

    private func removeEmptyAssistantMessage(id: UUID?) {
        guard let id else { return }
        messages.removeAll { $0.id == id && $0.content.isEmpty }
    }

    private func showStreamFailure(_ message: String, assistantId: UUID?) {
        if let assistantId, let index = messages.firstIndex(where: { $0.id == assistantId }) {
            messages[index].content = message
        } else {
            messages.append(StarSeaMessage(role: .assistant, content: message))
        }
        errorMessage = message
    }

    private func requestLeave() {
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
        isSettlementEditorFocused = false
        isLeaveConfirmationPresented = false
        isSettlementSheetPresented = false

        Task { @MainActor in
            await Task.yield()
            onLeave()
        }
    }
}

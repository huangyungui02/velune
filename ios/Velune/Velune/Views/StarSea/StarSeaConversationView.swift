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
    @State private var activeTask: Task<Void, Never>?
    @State private var isLeaveConfirmationPresented = false
    @State private var settledGlimmer: StarSeaStreamService.SettledGlimmer?
    @State private var settlementText = ""
    @State private var isEditingSettlement = false
    @State private var isSettlementSheetPresented = false
    @State private var settlementSheetDetent = PresentationDetent.medium
    @State private var isSavingSettlement = false
    @FocusState private var isComposerFocused: Bool
    @FocusState private var isSettlementEditorFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StarryBackgroundView()

            VStack(spacing: 0) {
                messageList
                if settledGlimmer == nil {
                    composer
                } else {
                    settlementCard
                }
            }
        }
        .highPriorityGesture(backSwipeGesture)
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
            "starsea.leave.title",
            isPresented: $isLeaveConfirmationPresented,
            titleVisibility: .visible
        ) {
            Button("starsea.leave.settle") {
                Task { await settleAndLeave() }
            }
            .disabled(threadId == nil || isSettling || settledGlimmer != nil)

            Button("starsea.leave.direct", role: .destructive) {
                leaveDirectly()
            }

            Button("common.cancel", role: .cancel) {}
        } message: {
            Text("starsea.leave.message")
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
                isEditing: isEditingSettlement,
                isSaving: isSavingSettlement,
                isEditorFocused: $isSettlementEditorFocused,
                onEdit: editSettlement,
                onSave: saveSettlement
            )
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

    private var settlementCard: some View {
        StarSeaSettlementSummaryCard(
            text: settlementText,
            isSaving: isSavingSettlement,
            onOpen: openSettlementSheet,
            onEdit: editSettlement,
            onSave: saveSettlement
        )
        .padding()
    }

    private var canSendMessage: Bool {
        !isStreaming
            && !isSettling
            && settledGlimmer == nil
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && threadId != nil
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
        guard !content.isEmpty, threadId != nil, settledGlimmer == nil else { return }

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
        guard !isStreaming, settledGlimmer == nil else { return }

        isStreaming = true
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
                    removeEmptyAssistantMessage(id: assistantId)
                    errorMessage = error.localizedDescription
                }
            }

            await MainActor.run {
                isStreaming = false
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
                if case let .settled(glimmer) = event {
                    presentSettlement(glimmer)
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
        case let .done(threadId):
            if let threadId {
                self.threadId = threadId
            }
        case let .settled(glimmer):
            removeEmptyAssistantMessage(id: assistantId)
            presentSettlement(glimmer)
        }
    }

    private func presentSettlement(_ glimmer: StarSeaStreamService.SettledGlimmer) {
        settledGlimmer = glimmer
        settlementText = glimmer.content
        isEditingSettlement = false
        isSettlementSheetPresented = true
        settlementSheetDetent = .medium
        isSavingSettlement = false
        isSettling = false
        isComposerFocused = false
        activeTask?.cancel()
        activeTask = nil
    }

    private func openSettlementSheet() {
        isEditingSettlement = false
        settlementSheetDetent = .medium
        isSettlementEditorFocused = false
        isSettlementSheetPresented = true
    }

    private func editSettlement() {
        isSettlementSheetPresented = true
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
        guard let settledGlimmer, !isSavingSettlement else { return }

        let content = settlementText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSavingSettlement = true
        errorMessage = nil

        do {
            try await Glimmer.updateContent(id: settledGlimmer.id, content: content)
            leaveDirectly()
        } catch {
            errorMessage = error.localizedDescription
            isSavingSettlement = false
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

    private func requestLeave() {
        guard settledGlimmer == nil else { return }
        isLeaveConfirmationPresented = true
    }

    private func leaveDirectly() {
        activeTask?.cancel()
        activeTask = nil
        onLeave()
    }
}

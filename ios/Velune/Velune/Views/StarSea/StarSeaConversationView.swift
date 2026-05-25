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
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    let lastMessageId = messages.last?.id

                    ForEach(messages) { message in
                        VStack(spacing: 8) {
                            let payload = starSeaPayload(for: message)

                            ConversationMessageRow(
                                role: message.role == .user ? .user : .assistant,
                                content: payload.body
                            )

                            if message.id == lastMessageId, !payload.options.isEmpty {
                                ConversationOptionsView(
                                    options: payload.options,
                                    isDisabled: isStreaming || isSettling || threadId == nil
                                ) { option in
                                    selectConversationOption(option)
                                }
                                .padding(.top, 2)
                            }
                        }
                        .id(message.id)
                    }

                    if !resonanceMatches.isEmpty {
                        StarSeaResonanceMatchesView(matches: resonanceMatches)
                            .id("resonance-matches")
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(.rect)
            .onTapGesture {
                isComposerFocused = false
            }
            .onChange(of: messages.count) { _, _ in
                scrollToLatest(with: proxy, animated: true)
            }
            .onChange(of: messages.last?.content) { _, _ in
                scrollToLatest(with: proxy, animated: false)
            }
            .onChange(of: resonanceMatches) { _, _ in
                scrollToLatest(with: proxy, animated: true)
            }
        }
    }

    private var composer: some View {
        let canSend = !isStreaming
            && !isSettling
            && settledGlimmer == nil
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && threadId != nil

        return HStack(alignment: .center, spacing: 10) {
            TextField("starsea.chat.placeholder", text: $inputText, axis: .vertical)
                .focused($isComposerFocused)
                .lineLimit(1 ... 4)
                .textFieldStyle(.plain)
                .font(.footnote)
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)
                .submitLabel(.send)
                .padding(.leading, 18)
                .padding(.vertical, 13)

            Button {
                Task { await sendFollowUp() }
            } label: {
                if isStreaming || isSettling {
                    ProgressView()
                        .tint(UITheme.primaryText.opacity(0.8))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(0.06), in: .circle)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(canSend ? UITheme.primaryText : UITheme.primaryText.opacity(0.24))
                        .frame(width: 32, height: 32)
                        .background(.white.opacity(canSend ? 0.08 : 0.02), in: .circle)
                }
            }
            .disabled(!canSend)
            .scaleEffect(canSend ? 1 : 0.94)
            .padding(.trailing, 8)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canSend)
        }
        .frame(minHeight: 46)
        .background(Color(red: 0.03, green: 0.035, blue: 0.055).opacity(0.60), in: .capsule)
        .glassEffect(in: .capsule)
        .overlay {
            Capsule()
                .stroke(.white.opacity(isComposerFocused ? 0.15 : 0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    private var settlementCard: some View {
        StarSeaSettlementCard(
            text: $settlementText,
            isEditing: isEditingSettlement,
            isSaving: isSavingSettlement,
            isEditorFocused: $isSettlementEditorFocused,
            onEdit: editSettlement,
            onSave: saveSettlement
        )
        .padding()
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

    private func starSeaPayload(for message: StarSeaMessage) -> ConversationOptionPayload {
        guard message.role == .assistant else {
            return ConversationOptionPayload(body: message.content, options: [])
        }

        return ConversationOptionParser.parse(message.content)
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
        isSavingSettlement = false
        isSettling = false
        isComposerFocused = false
        activeTask?.cancel()
        activeTask = nil
    }

    private func editSettlement() {
        isEditingSettlement = true
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

    private func scrollToLatest(with proxy: ScrollViewProxy, animated: Bool) {
        let target: AnyHashable? = resonanceMatches.isEmpty
            ? messages.last?.id
            : AnyHashable("resonance-matches")
        guard let target else { return }

        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}

struct StarSeaMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case assistant
    }

    let id: UUID
    let role: Role
    var content: String

    init(id: UUID = UUID(), role: Role, content: String) {
        self.id = id
        self.role = role
        self.content = content
    }
}

private struct StarSeaResonanceMatchesView: View {
    let matches: [StarSeaStreamService.ResonanceMatch]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("starsea.resonance.title")
                .font(.system(size: 11, weight: .light))
                .tracking(2.0)
                .foregroundStyle(UITheme.tertiaryText.opacity(0.6))
                .padding(.leading, 6)

            ForEach(matches) { match in
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(.white.opacity(0.06))
                            .frame(width: 48, height: 48)

                        Text(String(match.name.prefix(1)))
                            .font(.system(size: 19, weight: .medium))
                            .foregroundStyle(UITheme.primaryText.opacity(0.86))
                    }
                    .overlay {
                        Circle()
                            .stroke(.white.opacity(0.09), lineWidth: 0.5)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text(match.name)
                            .font(.system(size: 14, weight: .medium))
                            .tracking(1.5)
                            .foregroundStyle(UITheme.primaryText.opacity(0.9))
                            .lineLimit(1)

                        Text(match.line)
                            .font(.system(size: 12, weight: .light))
                            .tracking(0.8)
                            .foregroundStyle(UITheme.secondaryText.opacity(0.62))
                            .lineLimit(2)
                    }

                    Spacer(minLength: 0)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(UITheme.primaryText.opacity(0.24))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.07, green: 0.075, blue: 0.095).opacity(0.30), in: .rect(cornerRadius: 18))
                .glassEffect(in: .rect(cornerRadius: 18))
                .overlay {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(.white.opacity(0.06), lineWidth: 0.5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StarSeaSettlementCard: View {
    @Binding var text: String
    let isEditing: Bool
    let isSaving: Bool
    let isEditorFocused: FocusState<Bool>.Binding
    let onEdit: () -> Void
    let onSave: () -> Void

    private var canSave: Bool {
        !isSaving && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("starsea.settlement.title")
                .font(.headline.weight(.semibold))
                .foregroundStyle(UITheme.primaryText)

            if isEditing {
                editor
            } else {
                Text(text)
                    .font(.body)
                    .lineSpacing(7)
                    .foregroundStyle(UITheme.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            actions
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.07), in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        }
    }

    private var editor: some View {
        TextEditor(text: $text)
            .focused(isEditorFocused)
            .font(.body)
            .lineSpacing(7)
            .foregroundStyle(UITheme.primaryText)
            .tint(UITheme.primaryText)
            .scrollContentBackground(.hidden)
            .frame(minHeight: 180, maxHeight: 280)
            .padding(10)
            .background(.white.opacity(0.05), in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(.white.opacity(0.1), lineWidth: 0.5)
            }
            .accessibilityLabel(Text("starsea.settlement.editor"))
    }

    private var actions: some View {
        HStack(spacing: 10) {
            Button(action: onEdit) {
                Label("starsea.settlement.edit", systemImage: "pencil")
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(UITheme.primaryText)
            .opacity(isEditing ? 0.45 : 1)
            .disabled(isEditing || isSaving)

            Spacer()

            Button(action: onSave) {
                HStack(spacing: 8) {
                    if isSaving {
                        ProgressView()
                            .tint(.black)
                    } else {
                        Image(systemName: "checkmark")
                    }

                    Text("starsea.settlement.save")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 16)
                .frame(height: 38)
                .background(.white, in: .capsule)
            }
            .buttonStyle(.plain)
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.45)
        }
    }
}

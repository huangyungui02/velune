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
    @FocusState private var isComposerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            StarryBackgroundView()

            VStack(spacing: 0) {
                messageList
                composer
            }
        }
        .highPriorityGesture(backSwipeGesture)
        .navigationBarBackButtonHidden(true)
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
            .disabled(threadId == nil || isSettling)

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
                .padding()
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
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && threadId != nil

        return HStack(alignment: .bottom, spacing: 6) {
            TextField("starsea.chat.placeholder", text: $inputText, axis: .vertical)
                .focused($isComposerFocused)
                .lineLimit(1 ... 4)
                .textFieldStyle(.plain)
                .font(.body)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)
                .padding(.leading, 16)
                .padding(.trailing, 4)
                .padding(.vertical, 14)

            Button {
                Task { await sendFollowUp() }
            } label: {
                if isStreaming || isSettling {
                    ProgressView()
                        .tint(.black)
                        .frame(width: 36, height: 36)
                        .background(.white.opacity(0.8), in: .circle)
                } else {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(.white, in: .circle)
                }
            }
            .disabled(!canSend)
            .opacity(canSend ? 1.0 : 0.45)
            .scaleEffect(canSend ? 1 : 0.94)
            .padding(.trailing, 6)
            .padding(.bottom, 6)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canSend)
        }
        .background(Color.clear, in: .rect(cornerRadius: 24))
        .glassEffect(in: .rect(cornerRadius: 24))
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
        guard !content.isEmpty, threadId != nil else { return }

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
        guard !isStreaming else { return }

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
                if case .settled = event {
                    leaveDirectly()
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
        case .settled:
            break
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
        VStack(alignment: .leading, spacing: 8) {
            ForEach(matches) { match in
                VStack(alignment: .leading, spacing: 6) {
                    Text(match.name)
                        .font(.subheadline.weight(.semibold))
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.primaryText)
                        .lineLimit(1)

                    Text(match.line)
                        .font(.footnote)
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.secondaryText)
                        .lineLimit(3)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .frame(maxWidth: 320, alignment: .leading)
                .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.08), lineWidth: 0.5)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

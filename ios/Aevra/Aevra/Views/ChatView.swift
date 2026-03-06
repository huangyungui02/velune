import MarkdownUI
import SwiftUI

struct ChatView: View {
    let sessionId: UUID
    let soulerId: UUID
    let soulerName: String
    let focusComposerOnAppear: Bool
    let onSelectSession: ((ChatSession) -> Void)?

    @State private var activeSessionId: UUID
    @State private var isDraftSession = false
    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var hasScrolledToLatestOnAppear = false
    @State private var sessions: [ChatSession] = []
    @State private var isLoadingSessions = false
    @State private var sessionMenuError: String?
    @State private var isShowingSouler = false
    @FocusState private var isComposerFocused: Bool

    init(
        sessionId: UUID,
        soulerId: UUID,
        soulerName: String,
        focusComposerOnAppear: Bool = false,
        onSelectSession: ((ChatSession) -> Void)? = nil
    ) {
        self.sessionId = sessionId
        self.soulerId = soulerId
        self.soulerName = soulerName
        self.focusComposerOnAppear = focusComposerOnAppear
        self.onSelectSession = onSelectSession
        _activeSessionId = State(initialValue: sessionId)
    }

    var body: some View {
        ZStack {
            BackgroundView()

            ZStack {
                VStack(spacing: 0) {
                    if isLoading, messages.isEmpty {
                        ProgressView("common.loading")
                            .tint(UITheme.accent)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if messages.isEmpty {
                        EmptyView(title: "resonance.chat.empty")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        messageList
                    }

                    composer
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button {
                    isShowingSouler = true
                } label: {
                    Text(soulerName)
                        .lineLimit(1)
                }
                .accessibilityLabel(Text("resonance.chat.action.profile"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button {
                        startNewConversation()
                    } label: {
                        Label("resonance.chat.action.newConversation", systemImage: "plus.bubble")
                    }

                    Divider()

                    if let sessionMenuError {
                        Section {
                            Text(sessionMenuError)
                            Button("common.retry") {
                                Task { await loadSessionsForSidebar() }
                            }
                        }
                    } else if isLoadingSessions, sidebarSessions.isEmpty {
                        Section {
                            Label("common.loading", systemImage: "hourglass")
                        }
                    } else if sidebarSessions.isEmpty {
                        Section {
                            Text("resonance.empty")
                        }
                    } else {
                        Section {
                            ForEach(sidebarSessions) { session in
                                Button {
                                    openSession(session)
                                } label: {
                                    Label(
                                        session.hasTitle ? session.title : session.soulerName,
                                        systemImage: selectedSessionId == session.id ? "checkmark" : "message"
                                    )
                                }
                            }
                        }
                    }
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel(Text("starsea.action.resonances"))
            }
        }
        .alert("matching.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            } else {
                Text("matching.error.unknown")
            }
        }
        .onChange(of: sessionId) { _, newValue in
            guard newValue != activeSessionId else { return }
            activeSessionId = newValue
            isDraftSession = false
        }
        .task(id: activeSessionId) {
            await prepareConversation()
            await loadSessionsForSidebar()
        }
        .onAppear {
            guard focusComposerOnAppear else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                isComposerFocused = true
            }
        }
        .navigationDestination(isPresented: $isShowingSouler) {
            SoulerView(soulerId: soulerId)
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ResonanceChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onAppear {
                guard !hasScrolledToLatestOnAppear else { return }
                hasScrolledToLatestOnAppear = true
                scrollToLatest(with: proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToLatest(with: proxy, animated: true)
            }
            .onChange(of: messages.last?.content) { _, _ in
                scrollToLatest(with: proxy, animated: false)
            }
        }
    }

    private var composer: some View {
        let canSend = !isSending && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return HStack(alignment: .bottom, spacing: 10) {
            TextField(
                "resonance.chat.placeholder",
                text: $inputText,
                axis: .vertical
            )
            .focused($isComposerFocused)
            .lineLimit(1 ... 4)
            .textFieldStyle(.plain)
            .font(.body)
            .fontDesign(.serif)
            .foregroundStyle(UITheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.clear, in: .rect(cornerRadius: 18))
            .glassEffect(in: .rect(cornerRadius: 18))

            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(canSend ? UITheme.primaryText : UITheme.tertiaryText)
                    .frame(width: 45, height: 45)
                    .background(Color.clear, in: .circle)
                    .glassEffect(in: .circle)
            }
            .disabled(!canSend)
            .scaleEffect(canSend ? 1 : 0.96)
            .animation(.spring(response: 0.25, dampingFraction: 0.8), value: canSend)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .padding(.horizontal)
        .padding(.bottom, 6)
    }

    @MainActor
    private func prepareConversation() async {
        messages = []
        inputText = ""
        errorMessage = nil
        hasScrolledToLatestOnAppear = false
        await loadMessages()
    }

    private func scrollToLatest(with proxy: ScrollViewProxy, animated: Bool) {
        guard let lastId = messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    @MainActor
    private func loadMessages() async {
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await Message.getHistory(sessionId: activeSessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func sendMessage() async {
        if isSending { return }

        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        inputText = ""
        defer { isSending = false }

        let userLocal = Message(
            id: UUID(),
            soulerId: soulerId,
            sessionId: activeSessionId,
            role: .user,
            content: content,
            createdAt: .now
        )
        messages.append(userLocal)

        let assistantLocalId = UUID()
        let assistantLocal = Message(
            id: assistantLocalId,
            soulerId: soulerId,
            sessionId: activeSessionId,
            role: .assistant,
            content: "",
            createdAt: .now
        )
        messages.append(assistantLocal)

        do {
            var resolvedSessionId: UUID?
            var resolvedTitle: String?
            let startedFromDraft = isDraftSession
            for try await event in ChatStreamService.streamReply(
                sessionId: isDraftSession ? nil : activeSessionId,
                soulerId: soulerId,
                soulerName: soulerName,
                content: content
            ) {
                switch event {
                case let .delta(delta):
                    if let index = messages.firstIndex(where: { $0.id == assistantLocalId }) {
                        messages[index].content += delta
                    }
                case let .done(payload):
                    if let sessionId = payload.sessionId {
                        resolvedSessionId = sessionId
                    }
                    if let title = payload.title?
                        .trimmingCharacters(in: .whitespacesAndNewlines),
                        !title.isEmpty
                    {
                        resolvedTitle = title
                    }
                }
            }
            if let resolvedSessionId {
                activeSessionId = resolvedSessionId
                isDraftSession = false
            }
            messages = try await Message.getHistory(
                sessionId: resolvedSessionId ?? activeSessionId
            )
            await loadSessionsForSidebar()
            if startedFromDraft, let resolvedSessionId, let onSelectSession {
                let fallbackTitle = resolvedTitle ?? String(localized: "resonance.chat.newConversation")
                let routeSession = sessions.first(where: { $0.id == resolvedSessionId }) ?? ChatSession(
                    id: resolvedSessionId,
                    soulerId: soulerId,
                    soulerName: soulerName,
                    title: fallbackTitle,
                    createdAt: .now,
                    updatedAt: .now
                )
                onSelectSession(routeSession)
            }
        } catch {
            messages.removeAll { $0.id == assistantLocalId }
            errorMessage = error.localizedDescription
        }
    }

    private var selectedSessionId: UUID {
        activeSessionId
    }

    private var sidebarSessions: [ChatSession] {
        if !isDraftSession {
            return sessions
        }

        let placeholder = ChatSession(
            id: activeSessionId,
            soulerId: soulerId,
            soulerName: soulerName,
            title: String(localized: "resonance.chat.newConversation"),
            createdAt: .now,
            updatedAt: .now
        )
        return [placeholder] + sessions.filter { $0.id != activeSessionId }
    }

    @MainActor
    private func loadSessionsForSidebar() async {
        if isLoadingSessions { return }
        isLoadingSessions = true
        defer { isLoadingSessions = false }

        do {
            sessions = try await ChatSession.getPage(soulerId: soulerId, limit: 20, offset: 0)
            sessionMenuError = nil
        } catch {
            sessionMenuError = error.localizedDescription
            sessions = []
        }
    }

    @MainActor
    private func openSession(_ session: ChatSession) {
        guard session.id != activeSessionId else { return }
        isDraftSession = false
        if let onSelectSession {
            onSelectSession(session)
            return
        }
        activeSessionId = session.id
    }

    @MainActor
    private func startNewConversation() {
        if isDraftSession, messages.isEmpty {
            return
        }
        activeSessionId = UUID()
        isDraftSession = true
        messages = []
        inputText = ""
        errorMessage = nil
        hasScrolledToLatestOnAppear = false
    }
}

private struct ResonanceChatBubble: View {
    let message: Message

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 32)
            }

            Markdown(message.content)
                .markdownTextStyle {
                    ForegroundColor(UITheme.primaryText)
                }
                .fontDesign(.serif)
                .lineSpacing(5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                        ? .white.opacity(0.16)
                        : .white.opacity(0.08),
                    in: .rect(cornerRadius: 14)
                )
                .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)

            if !isUser {
                Spacer(minLength: 32)
            }
        }
    }
}

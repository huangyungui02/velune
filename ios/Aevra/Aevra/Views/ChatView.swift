import MarkdownUI
import SwiftUI

struct ChatView: View {
    @Environment(\.dismiss) private var dismiss

    let sessionId: UUID
    let soulerId: UUID
    let soulerName: String
    let initialReply: String?
    let onOpenSeaStar: (() -> Void)?
    let onSelectSession: ((ChatSession) -> Void)?

    @State private var messages: [Message] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?
    @State private var autoRepliedSessionId: UUID?
    @State private var hasScrolledToLatestOnAppear = false
    @State private var sessions: [ChatSession] = []
    @State private var isLoadingSessions = false
    @State private var sessionMenuError: String?
    @State private var isSidebarPresented = false
    @State private var pushedSession: ChatSession?

    private let sidebarWidth: CGFloat = 320

    init(
        sessionId: UUID,
        soulerId: UUID,
        soulerName: String,
        initialReply: String? = nil,
        onOpenSeaStar: (() -> Void)? = nil,
        onSelectSession: ((ChatSession) -> Void)? = nil
    ) {
        self.sessionId = sessionId
        self.soulerId = soulerId
        self.soulerName = soulerName
        self.initialReply = initialReply
        self.onOpenSeaStar = onOpenSeaStar
        self.onSelectSession = onSelectSession
    }

    var body: some View {
        ZStack(alignment: .leading) {
            ZStack {
                BackgroundView()

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
            .offset(x: sidebarOpenOffset)
            .disabled(sidebarProgress > 0.01)

            if sidebarProgress > 0.001 {
                Color.black.opacity(0.3 * sidebarProgress)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSidebarPresented = false
                        }
                    }
            }

            sidebarView
                .offset(x: sidebarOpenOffset - sidebarWidth)
        }
        .navigationTitle(soulerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    withAnimation(.easeInOut(duration: 0.22)) {
                        isSidebarPresented.toggle()
                    }
                } label: {
                    Image(systemName: "line.3.horizontal")
                }
                .accessibilityLabel(Text("seastar.action.resonances"))
            }

            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SoulerView(soulerId: soulerId)
                } label: {
                    Image(systemName: "person.text.rectangle")
                }
                .accessibilityLabel(Text("resonance.chat.action.profile"))
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
        .animation(.easeInOut(duration: 0.22), value: isSidebarPresented)
        .task(id: sessionId) {
            await prepareConversation()
            await loadSessionsForSidebar()
        }
        .navigationDestination(item: $pushedSession) { session in
            ChatView(
                sessionId: session.id,
                soulerId: session.soulerId,
                soulerName: session.soulerName,
                onOpenSeaStar: onOpenSeaStar,
                onSelectSession: onSelectSession
            )
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
        await triggerInitialReplyIfNeeded()
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
            messages = try await Message.getHistory(sessionId: sessionId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func sendMessage(
        contentOverride: String? = nil
    ) async {
        if isSending { return }

        let content = (contentOverride ?? inputText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        if contentOverride == nil {
            inputText = ""
        }
        defer { isSending = false }

        let userLocal = Message(
            id: UUID(),
            soulerId: soulerId,
            sessionId: sessionId,
            role: .user,
            content: content,
            createdAt: .now
        )
        messages.append(userLocal)

        let assistantLocalId = UUID()
        let assistantLocal = Message(
            id: assistantLocalId,
            soulerId: soulerId,
            sessionId: sessionId,
            role: .assistant,
            content: "",
            createdAt: .now
        )
        messages.append(assistantLocal)

        do {
            for try await event in ChatStreamService.streamReply(
                sessionId: sessionId,
                content: content
            ) {
                switch event {
                case let .delta(delta):
                    if let index = messages.firstIndex(where: { $0.id == assistantLocalId }) {
                        messages[index].content += delta
                    }
                case .done:
                    break
                }
            }
            messages = try await Message.getHistory(sessionId: sessionId)
        } catch {
            messages.removeAll { $0.id == assistantLocalId }
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func triggerInitialReplyIfNeeded() async {
        guard autoRepliedSessionId != sessionId else { return }

        let reply = initialReply?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !reply.isEmpty else { return }

        autoRepliedSessionId = sessionId
        await sendMessage(contentOverride: reply)
    }

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                openSeaStar()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "sparkles")
                    Text("SeaStar")
                        .font(.body.weight(.semibold))
                        .fontDesign(.serif)
                }
                .foregroundStyle(UITheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.clear, in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Divider()
                .overlay(.white.opacity(0.12))
                .padding(.bottom, 2)

            Group {
                if let sessionMenuError {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(sessionMenuError)
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)

                        Button("common.retry") {
                            Task { await loadSessionsForSidebar() }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 8)
                } else if isLoadingSessions, sessions.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("common.loading")
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)
                    }
                    .padding(.top, 8)
                } else if sessions.isEmpty {
                    Text("resonance.empty")
                        .font(.footnote)
                        .foregroundStyle(UITheme.secondaryText)
                        .padding(.top, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(sessions) { session in
                                Button {
                                    openSession(session)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: selectedSessionId == session.id ? "checkmark" : "message")
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(UITheme.primaryText)

                                        Text(session.hasTitle ? session.title : session.soulerName)
                                            .lineLimit(1)
                                            .font(.body.weight(.medium))
                                            .fontDesign(.serif)
                                            .foregroundStyle(UITheme.primaryText)

                                        Spacer(minLength: 8)

                                        Text(session.updatedAt, format: .relative(presentation: .named))
                                            .font(.caption)
                                            .foregroundStyle(UITheme.secondaryText)
                                            .lineLimit(1)
                                            .monospacedDigit()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        selectedSessionId == session.id ? .white.opacity(0.15) : .clear,
                                        in: .rect(cornerRadius: 12)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: sidebarWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(width: 1),
            alignment: .trailing
        )
    }

    private var selectedSessionId: UUID {
        sessionId
    }

    private var sidebarOpenOffset: CGFloat {
        isSidebarPresented ? sidebarWidth : 0
    }

    private var sidebarProgress: CGFloat {
        guard sidebarWidth > 0 else { return 0 }
        return sidebarOpenOffset / sidebarWidth
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
    private func openSeaStar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSidebarPresented = false
        }
        if let onOpenSeaStar {
            onOpenSeaStar()
            return
        }
        dismiss()
    }

    @MainActor
    private func openSession(_ session: ChatSession) {
        withAnimation(.easeInOut(duration: 0.2)) {
            isSidebarPresented = false
        }
        guard session.id != sessionId else { return }
        if let onSelectSession {
            onSelectSession(session)
            return
        }
        pushedSession = session
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

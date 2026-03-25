import MarkdownUI
import SwiftData
import SwiftUI

struct ChatView: View {
    struct DraftPrelude: Hashable {
        let glimmerContent: String
        let echoContent: String
    }

    let sessionId: UUID?
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
    @State private var showPaywall = false
    @State private var draftEchoId: UUID?
    @State private var activeDraftPrelude: DraftPrelude?
    @State private var hasPerformedInitialLoad = false
    @State private var shouldPauseAutoScrollDuringStreaming = false
    @State private var billingErrorContext: BillingErrorContext?
    @FocusState private var isComposerFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext

    init(
        sessionId: UUID?,
        echoId: UUID? = nil,
        draftPrelude: DraftPrelude? = nil,
        soulerId: UUID,
        soulerName: String,
        focusComposerOnAppear: Bool = false,
        onSelectSession: ((ChatSession) -> Void)? = nil
    ) {
        let isDraft = sessionId == nil
        self.sessionId = sessionId
        self.soulerId = soulerId
        self.soulerName = soulerName
        self.focusComposerOnAppear = focusComposerOnAppear
        self.onSelectSession = onSelectSession
        _activeSessionId = State(initialValue: sessionId ?? UUID())
        _isDraftSession = State(initialValue: isDraft)
        _draftEchoId = State(initialValue: isDraft ? echoId : nil)
        _activeDraftPrelude = State(initialValue: isDraft ? draftPrelude : nil)
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
                            .contentShape(.rect)
                            .onTapGesture(perform: dismissComposer)
                    } else if messages.isEmpty {
                        EmptyView(title: "resonance.chat.empty")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .contentShape(.rect)
                            .onTapGesture(perform: dismissComposer)
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
            }
        }
        .alert("matching.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: {
                if !$0 {
                    errorMessage = nil
                    billingErrorContext = nil
                }
            }
        )) {
            if billingErrorContext?.shouldOfferUpgrade == true {
                Button("billing.action.openPaywall") {
                    showPaywall = true
                }
            }
            Button("common.ok", role: .cancel) {}
        } message: {
            if let errorMessage {
                Text(errorMessage)
            } else {
                Text("matching.error.unknown")
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: sessionId) { _, newValue in
            guard let newValue, newValue != activeSessionId else { return }
            Task {
                await switchToExistingSession(newValue)
            }
        }
        .task {
            guard !hasPerformedInitialLoad else { return }
            hasPerformedInitialLoad = true
            await prepareConversation()
            await loadSessionsForSidebar()
        }
        .onAppear {
            if focusComposerOnAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                    isComposerFocused = true
                }
            } else {
                isComposerFocused = false
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
            .scrollDismissesKeyboard(.interactively)
            .contentShape(.rect)
            .onTapGesture(perform: dismissComposer)
            .onAppear {
                guard !hasScrolledToLatestOnAppear else { return }
                hasScrolledToLatestOnAppear = true
                scrollToLatest(with: proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToLatest(with: proxy, animated: true, reason: .countChanged)
            }
            .onChange(of: messages.last?.content) { _, _ in
                scrollToLatest(with: proxy, animated: false, reason: .contentChanged)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if isSending {
                            shouldPauseAutoScrollDuringStreaming = true
                        }
                    }
            )
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
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.clear, in: .rect(cornerRadius: 16))
            .glassEffect(in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(isComposerFocused ? 0.18 : 0.10), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.10), radius: 14, y: 2)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isComposerFocused)

            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canSend ? UITheme.primaryText : UITheme.tertiaryText)
                    .frame(width: 40, height: 40)
                    .background(Color.clear, in: .circle)
                    .glassEffect(in: .circle)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(canSend ? 0.16 : 0.08), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(canSend ? 0.12 : 0.08), radius: 12, y: 2)
            }
            .disabled(!canSend)
            .scaleEffect(canSend ? 1 : 0.94)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canSend)
        }
        .padding(.horizontal, 8)
        .padding(.top, 10)
        .padding(.bottom, 8)
        .padding(.horizontal, 10)
        .padding(.bottom, 6)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isSending)
    }

    @MainActor
    private func prepareConversation() async {
        messages = []
        inputText = ""
        errorMessage = nil
        billingErrorContext = nil
        hasScrolledToLatestOnAppear = false
        if isDraftSession {
            applyDraftPreludeIfNeeded()
            return
        }
        await loadMessages()
    }

    private enum ScrollTrigger {
        case countChanged
        case contentChanged
    }

    private func scrollToLatest(with proxy: ScrollViewProxy, animated: Bool, reason: ScrollTrigger? = nil) {
        if isSending, shouldPauseAutoScrollDuringStreaming, reason != nil {
            return
        }
        guard let lastId = messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }

    private func dismissComposer() {
        isComposerFocused = false
    }

    @MainActor
    private func loadMessages() async {
        if isDraftSession {
            messages = []
            return
        }
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await Message.getHistory(sessionId: activeSessionId)
        } catch {
            errorMessage = error.localizedDescription
            billingErrorContext = error.billingErrorContext
        }
    }

    @MainActor
    private func sendMessage() async {
        if isSending { return }

        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        shouldPauseAutoScrollDuringStreaming = false
        dismissComposer()
        inputText = ""
        defer {
            isSending = false
            shouldPauseAutoScrollDuringStreaming = false
        }

        let assistantLocalId = appendPendingMessages(for: content)

        do {
            var resolvedSessionId: UUID?
            var resolvedTitle: String?
            let startedFromDraft = isDraftSession
            for try await event in ChatStreamService.streamReply(
                sessionId: isDraftSession ? nil : activeSessionId,
                echoId: isDraftSession ? draftEchoId : nil,
                soulerId: soulerId,
                soulerName: soulerName,
                path: "\(AppLanguage.current.apiLanguageCode)/chat",
                content: content
            ) {
                switch event {
                case let .delta(delta):
                    if let index = messages.firstIndex(where: { $0.id == assistantLocalId }) {
                        messages[index].content += delta
                    }
                case let .done(payload):
                    let result = applyDonePayload(payload)
                    resolvedSessionId = result.sessionId ?? resolvedSessionId
                    resolvedTitle = result.title ?? resolvedTitle
                }
            }
            try await finalizeSend(
                resolvedSessionId: resolvedSessionId,
                resolvedTitle: resolvedTitle,
                startedFromDraft: startedFromDraft
            )
        } catch {
            messages.removeAll { $0.id == assistantLocalId }
            errorMessage = error.localizedDescription
            billingErrorContext = error.billingErrorContext
        }
    }

    @MainActor
    private func appendPendingMessages(for content: String) -> UUID {
        messages.append(
            Message(
                id: UUID(),
                soulerId: soulerId,
                sessionId: isDraftSession ? nil : activeSessionId,
                role: .user,
                content: content,
                createdAt: .now
            )
        )

        let assistantLocalId = UUID()
        messages.append(
            Message(
                id: assistantLocalId,
                soulerId: soulerId,
                sessionId: isDraftSession ? nil : activeSessionId,
                role: .assistant,
                content: "",
                createdAt: .now
            )
        )
        return assistantLocalId
    }

    @MainActor
    private func applyDonePayload(_ payload: ChatStreamService.DonePayload) -> (sessionId: UUID?, title: String?) {
        let title = payload.title?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (
            payload.sessionId,
            title.flatMap { $0.isEmpty ? nil : $0 }
        )
    }

    @MainActor
    private func finalizeSend(
        resolvedSessionId: UUID?,
        resolvedTitle: String?,
        startedFromDraft: Bool
    ) async throws {
        let sourceDraftEchoId = draftEchoId

        if let resolvedSessionId {
            activeSessionId = resolvedSessionId
            isDraftSession = false
            draftEchoId = nil
            activeDraftPrelude = nil

            if let sourceDraftEchoId {
                persistEchoSessionIdIfNeeded(
                    echoId: sourceDraftEchoId,
                    sessionId: resolvedSessionId
                )
            }
        }

        let sessionId = resolvedSessionId ?? activeSessionId
        messages = try await Message.getHistory(sessionId: sessionId)
        await loadSessionsForSidebar()

        guard startedFromDraft, let resolvedSessionId, let onSelectSession else { return }

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

    @MainActor
    private func persistEchoSessionIdIfNeeded(echoId: UUID, sessionId: UUID) {
        var descriptor = FetchDescriptor<Echo>(
            predicate: #Predicate { echo in
                echo.id == echoId
            }
        )
        descriptor.fetchLimit = 1

        guard let echo = try? modelContext.fetch(descriptor).first else { return }
        guard echo.sessionId != sessionId else { return }

        echo.sessionId = sessionId
        do {
            try modelContext.save()
        } catch {
            print("Failed to persist echo sessionId: \(error)")
        }
    }

    private var selectedSessionId: UUID {
        activeSessionId
    }

    private var sidebarSessions: [ChatSession] {
        sessions
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
        if let onSelectSession {
            onSelectSession(session)
            return
        }
        Task {
            await switchToExistingSession(session.id)
        }
    }

    @MainActor
    private func startNewConversation() {
        if isDraftSession, messages.isEmpty {
            return
        }
        activeSessionId = UUID()
        isDraftSession = true
        draftEchoId = nil
        activeDraftPrelude = nil
        messages = []
        inputText = ""
        errorMessage = nil
        billingErrorContext = nil
        hasScrolledToLatestOnAppear = false
    }

    @MainActor
    private func applyDraftPreludeIfNeeded() {
        guard let activeDraftPrelude else { return }

        let trimmedGlimmer = activeDraftPrelude.glimmerContent.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedEcho = activeDraftPrelude.echoContent.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedGlimmer.isEmpty {
            messages.append(
                Message(
                    id: UUID(),
                    soulerId: soulerId,
                    sessionId: nil,
                    role: .user,
                    content: trimmedGlimmer,
                    createdAt: .now
                )
            )
        }

        if !trimmedEcho.isEmpty {
            messages.append(
                Message(
                    id: UUID(),
                    soulerId: soulerId,
                    sessionId: nil,
                    role: .assistant,
                    content: trimmedEcho,
                    createdAt: .now
                )
            )
        }
    }

    @MainActor
    private func switchToExistingSession(_ sessionId: UUID) async {
        activeSessionId = sessionId
        isDraftSession = false
        draftEchoId = nil
        activeDraftPrelude = nil
        await prepareConversation()
        await loadSessionsForSidebar()
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

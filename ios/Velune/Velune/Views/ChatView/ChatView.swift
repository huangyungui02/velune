import SwiftData
import SwiftUI

struct ChatView: View {
    let logger = AppLogger.chat

    let sessionId: UUID?
    let soulerId: UUID
    let soulerName: String
    let focusComposerOnAppear: Bool
    let onSelectSession: ((ChatSession) -> Void)?

    @State var activeSessionId: UUID
    @State var isDraftSession = false
    @State var messages: [Message] = []
    @State var inputText = ""
    @State var isLoading = false
    @State var isSending = false
    @State var errorMessage: String?
    @State var hasScrolledToLatestOnAppear = false
    @State var sessions: [ChatSession] = []
    @State var isLoadingSessions = false
    @State var sessionMenuError: String?
    @State var isShowingSouler = false
    @State var hasPerformedInitialLoad = false
    @State var shouldPauseAutoScrollDuringStreaming = false
    @State var chapters: [SoulerChapter] = []
    @State var isLoadingChapters = false
    @State var isStartingChapterSession = false
    @State var selectedChapter: SoulerChapter?
    @FocusState var isComposerFocused: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.modelContext) var modelContext

    init(
        sessionId: UUID?,
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
    }

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 0) {
                if isLoading, messages.isEmpty {
                    ProgressView("common.loading")
                        .tint(UITheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                        .onTapGesture(perform: dismissComposer)
                } else if messages.isEmpty {
                    emptyConversationView
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(.rect)
                        .onTapGesture(perform: dismissComposer)
                } else {
                    messageList
                }

                composer
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
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
                    Group {
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
                                    Task { await syncConversationSessionsOnMenuAppear() }
                                }
                            }
                        } else if isLoadingSessions, conversationSessions.isEmpty {
                            Section {
                                Label("common.loading", systemImage: "hourglass")
                            }
                        } else if conversationSessions.isEmpty {
                            Section {
                                Text("resonance.chat.sessions.empty")
                            }
                        } else {
                            Section {
                                ForEach(conversationSessions) { session in
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
                    }
                    .onAppear {
                        Task { await syncConversationSessionsOnMenuAppear() }
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
                }
            }
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
            guard let newValue, newValue != activeSessionId else { return }
            Task {
                await switchToExistingSession(newValue)
            }
        }
        .task {
            guard !hasPerformedInitialLoad else { return }
            hasPerformedInitialLoad = true
            await loadConversationSessions()
            await prepareConversation()
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
}

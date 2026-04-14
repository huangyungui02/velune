import SwiftData
import SwiftUI

struct ChatView: View {
    let logger = AppLogger.chat

    struct DraftPrelude: Hashable {
        let stirringContent: String
        let echoContent: String
    }

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
    @State var showPaywall = false
    @State var draftEchoId: UUID?
    @State var activeDraftPrelude: DraftPrelude?
    @State var hasPerformedInitialLoad = false
    @State var shouldPauseAutoScrollDuringStreaming = false
    @State var billingErrorContext: BillingErrorContext?
    @State var chapters: [SoulerChapter] = []
    @State var isLoadingChapters = false
    @State var isStartingChapterSession = false
    @State var chapterOptions: [String] = []
    @State var selectedChapter: SoulerChapter?
    @FocusState var isComposerFocused: Bool
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.modelContext) var modelContext

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
                                Task { await loadConversationSessions() }
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
            await loadConversationSessions()
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

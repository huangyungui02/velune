import SwiftData
import SwiftUI

private struct ResonanceDraftChatTarget: Identifiable, Hashable {
    let soulerId: UUID
    let soulerName: String
    var id: UUID { soulerId }
}

struct ResonanceView: View {
    @Environment(\.modelContext) private var context
    @FocusState private var isSearchFocused: Bool
    @State private var authManager = AuthManager.shared
    @State private var activeSession: ChatSession?
    @State private var activeDraftChat: ResonanceDraftChatTarget?
    @State private var resonances: [Resonance] = []
    @State private var isSyncingResonances = false
    @State private var isLoadingMoreResonances = false
    @State private var hasMoreResonances = true
    @State private var resonanceMenuError: String?
    @State private var resonanceSearchText = ""
    let onOpenGlimmerComposer: () -> Void

    private let resonancePageSize = 20
    private let incrementalOverlapSeconds: TimeInterval = 1

    private var currentUserId: String? {
        authManager.currentUserId?.uuidString
    }

    private var isChatPresented: Bool {
        activeSession != nil || activeDraftChat != nil
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()

                if authManager.isAnonymous {
                    AppleSignInPromptCard(
                        icon: "bubble.left.and.bubble.right.fill",
                        title: "anonymous.restricted.resonance.title",
                        description: "anonymous.restricted.resonance.description"
                    )
                } else {
                    resonanceContent
                }
            }
            .navigationTitle("resonance.title")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(item: $activeSession) { session in
                ChatView(
                    sessionId: session.id,
                    soulerId: session.soulerId,
                    soulerName: session.soulerName,
                    focusComposerOnAppear: false
                )
            }
            .navigationDestination(item: $activeDraftChat) { draftTarget in
                ChatView(
                    sessionId: nil,
                    soulerId: draftTarget.soulerId,
                    soulerName: draftTarget.soulerName,
                    focusComposerOnAppear: false
                )
            }
        }
        .toolbar(isChatPresented ? .hidden : .visible, for: .tabBar)
        .task(id: authManager.currentUserId) {
            if authManager.isAnonymous || authManager.currentUserId == nil {
                resetResonanceState()
            } else {
                await loadResonances()
            }
        }
    }

    @ViewBuilder
    private var resonanceContent: some View {
        VStack(spacing: 12) {
            if !resonances.isEmpty {
                searchField
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
            }

            Group {
                if let resonanceMenuError {
                    centeredStatus {
                        Text(resonanceMenuError)
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)
                            .multilineTextAlignment(.center)

                        Button("common.retry") {
                            dismissSearch()
                            Task { await loadResonances() }
                        }
                        .font(.footnote.weight(.semibold))
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.primaryText)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 9)
                        .background(.white.opacity(0.12), in: .capsule)
                        .overlay {
                            Capsule()
                                .stroke(.white.opacity(0.2), lineWidth: 1)
                        }
                        .buttonStyle(.plain)
                    }
                } else if isSyncingResonances, resonances.isEmpty, hasMoreResonances {
                    centeredStatus {
                        ProgressView()
                            .tint(UITheme.primaryText)

                        Text("common.loading")
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)
                    }
                } else if displayedResonances.isEmpty {
                    if resonances.isEmpty, !hasActiveResonanceSearch {
                        SereneContentUnavailableView(
                            title: "starsea.empty.resonanceTitle",
                            symbol: "bubble.left.and.bubble.right",
                            subtitle: "starsea.empty.resonanceSubtitle",
                            actionTitle: "starsea.action.writeGlimmer",
                            action: onOpenGlimmerComposer
                        )
                    } else if hasActiveResonanceSearch {
                        ContentUnavailableView.search(text: resonanceSearchText)
                            .contentShape(.rect)
                            .onTapGesture(perform: dismissSearch)
                    } else {
                        ContentUnavailableView {
                            Label("resonance.empty", systemImage: "magnifyingglass")
                        }
                        .contentShape(.rect)
                        .onTapGesture(perform: dismissSearch)
                    }
                } else {
                    resonanceList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var searchField: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(UITheme.secondaryText)

            TextField("common.search", text: $resonanceSearchText)
                .focused($isSearchFocused)
                .submitLabel(.search)
                .textFieldStyle(.plain)
                .font(.footnote)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .glassEffect(in: .capsule)
    }

    private var resonanceList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(displayedResonances) { resonance in
                    Button {
                        dismissSearch()
                        openResonance(resonance)
                    } label: {
                        ResonanceRow(resonance: resonance)
                    }
                    .buttonStyle(.plain)
                }

                if isLoadingMoreResonances {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("common.loading")
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                } else if hasMoreResonances, !hasActiveResonanceSearch {
                    Color.clear
                        .frame(height: 1)
                        .onAppear {
                            Task { await loadMoreResonances() }
                        }
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 4)
            .padding(.bottom, 12)
        }
        .refreshable {
            await loadResonances()
        }
        .scrollDismissesKeyboard(.interactively)
        .contentShape(.rect)
        .onTapGesture(perform: dismissSearch)
    }

    private var hasActiveResonanceSearch: Bool {
        !resonanceSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var displayedResonances: [Resonance] {
        let keyword = resonanceSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return resonances }
        return resonances.filter {
            $0.soulerName.localizedCaseInsensitiveContains(keyword)
                || $0.lastSessionTitle.localizedCaseInsensitiveContains(keyword)
        }
    }

    private func centeredStatus<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 12) {
            content()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        .contentShape(.rect)
        .onTapGesture(perform: dismissSearch)
    }

    @MainActor
    private func resetResonanceState() {
        resonances = []
        isSyncingResonances = false
        isLoadingMoreResonances = false
        hasMoreResonances = true
        resonanceMenuError = nil
        resonanceSearchText = ""
    }

    @MainActor
    private func loadResonances() async {
        guard let userId = currentUserId else {
            resetResonanceState()
            return
        }

        let hasLocalCache = loadLocalResonances(userId: userId)
        await syncResonances(userId: userId, hasLocalCache: hasLocalCache)
    }

    @MainActor
    @discardableResult
    private func loadLocalResonances(userId: String) -> Bool {
        do {
            resonances = try Resonance.fetchCached(userId: userId, context: context)
            let state = SyncStateStore.state(userId: userId)
            hasMoreResonances = state.resonances.hasMore
            if !resonances.isEmpty {
                resonanceMenuError = nil
            }
            return !resonances.isEmpty
        } catch {
            resonances = []
            hasMoreResonances = true
            return false
        }
    }

    @MainActor
    private func syncResonances(userId: String, hasLocalCache: Bool) async {
        if isSyncingResonances { return }

        isSyncingResonances = true
        defer { isSyncingResonances = false }

        do {
            let currentState = SyncStateStore.state(userId: userId)
            let syncPayload = try await fetchSyncPayload(lastSyncedAt: currentState.resonances.lastSyncedAt)
            let hasChanges = try Resonance.mergeCached(syncPayload.items, userId: userId, context: context)

            if hasChanges {
                resonances = try Resonance.fetchCached(userId: userId, context: context)
            }

            let resolvedLastSyncedAt: Date?
            if let payloadLastSyncedAt = syncPayload.lastSyncedAt {
                resolvedLastSyncedAt = payloadLastSyncedAt
            } else if let currentLastSyncedAt = currentState.resonances.lastSyncedAt {
                resolvedLastSyncedAt = currentLastSyncedAt
            } else if syncPayload.items.isEmpty {
                resolvedLastSyncedAt = Date()
            } else {
                resolvedLastSyncedAt = nil
            }

            let nextState = SyncStateStore.SyncState(
                resonances: SyncStateStore.ResonancesSyncState(
                    lastSyncedAt: resolvedLastSyncedAt,
                    hasMore: syncPayload.hasMore ?? currentState.resonances.hasMore
                ),
                glimmers: currentState.glimmers
            )
            SyncStateStore.set(nextState, userId: userId)
            hasMoreResonances = nextState.resonances.hasMore
            resonanceMenuError = nil
        } catch {
            if !hasLocalCache && resonances.isEmpty {
                resonanceMenuError = error.localizedDescription
            }
        }
    }

    private func fetchSyncPayload(lastSyncedAt: Date?) async throws -> (items: [Resonance], lastSyncedAt: Date?, hasMore: Bool?) {
        if let lastSyncedAt {
            let updates = try await Resonance.getUpdatedSince(
                lastSyncedAt,
                pageSize: resonancePageSize,
                overlapSeconds: incrementalOverlapSeconds
            )
            let maxUpdatedAt = updates.map(\.updatedAt).max()
            let nextSyncedAt = maxUpdatedAt.map { max($0, lastSyncedAt) } ?? lastSyncedAt
            return (items: updates, lastSyncedAt: nextSyncedAt, hasMore: nil)
        } else {
            let page = try await Resonance.getPage(limit: resonancePageSize, offset: 0)
            return (
                items: page,
                lastSyncedAt: page.map(\.updatedAt).max(),
                hasMore: page.count == resonancePageSize
            )
        }
    }

    @MainActor
    private func loadMoreResonances() async {
        guard let userId = currentUserId else { return }
        guard !isSyncingResonances, !isLoadingMoreResonances, hasMoreResonances else { return }

        isLoadingMoreResonances = true
        defer { isLoadingMoreResonances = false }

        do {
            let page = try await Resonance.getPage(limit: resonancePageSize, offset: resonances.count)
            let hasChanges = try Resonance.mergeCached(page, userId: userId, context: context)
            if hasChanges {
                resonances = try Resonance.fetchCached(userId: userId, context: context)
            }

            hasMoreResonances = page.count == resonancePageSize
            let currentState = SyncStateStore.state(userId: userId)
            let pageMaxUpdatedAt = page.map(\.updatedAt).max()
            let nextSyncedAt: Date?
            if let pageMaxUpdatedAt {
                if let currentLastSyncedAt = currentState.resonances.lastSyncedAt {
                    nextSyncedAt = max(pageMaxUpdatedAt, currentLastSyncedAt)
                } else {
                    nextSyncedAt = pageMaxUpdatedAt
                }
            } else {
                nextSyncedAt = currentState.resonances.lastSyncedAt
            }

            SyncStateStore.set(
                SyncStateStore.SyncState(
                    resonances: SyncStateStore.ResonancesSyncState(
                        lastSyncedAt: nextSyncedAt,
                        hasMore: hasMoreResonances
                    ),
                    glimmers: currentState.glimmers
                ),
                userId: userId
            )
            resonanceMenuError = nil
        } catch {
            resonanceMenuError = error.localizedDescription
        }
    }

    private func openResonance(_ resonance: Resonance) {
        if let sessionId = resonance.lastSessionId {
            activeSession = ChatSession(
                id: sessionId,
                soulerId: resonance.soulerId,
                chapterId: nil,
                soulerName: resonance.soulerName,
                title: resonance.lastSessionTitle,
                updatedAt: resonance.updatedAt
            )
        } else {
            activeDraftChat = ResonanceDraftChatTarget(
                soulerId: resonance.soulerId,
                soulerName: resonance.soulerName
            )
        }
    }

    private func dismissSearch() {
        isSearchFocused = false
    }
}

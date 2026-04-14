import SwiftData
import SwiftUI

struct SidebarDraftChatTarget: Identifiable, Hashable {
    var soulerId: UUID
    var soulerName: String
    var id: UUID { soulerId }
}

struct SidebarNavigationState {
    var isSidebarPresented = false
    var activeSession: ChatSession?
    var activeDraftChat: SidebarDraftChatTarget?

    mutating func showSession(_ session: ChatSession) {
        activeSession = session
        activeDraftChat = nil
    }

    mutating func showDraftChat(_ draftTarget: SidebarDraftChatTarget) {
        activeSession = nil
        activeDraftChat = draftTarget
    }

    var selectedSoulerId: UUID? {
        activeSession?.soulerId ?? activeDraftChat?.soulerId
    }

    var isStarSeaDestination: Bool {
        activeSession == nil && activeDraftChat == nil
    }
}

struct SidebarContainer<Content: View>: View {
    @Binding var sidebarNavigation: SidebarNavigationState
    let sidebarWidth: CGFloat
    let isSidebarEnabled: Bool
    let onOpenStirringComposer: () -> Void
    let content: Content

    @State private var sidebarDragOffset: CGFloat = 0
    @FocusState private var isSidebarSearchFocused: Bool
    private let sidebarEdgeActivationWidth: CGFloat = 28

    init(
        sidebarNavigation: Binding<SidebarNavigationState>,
        sidebarWidth: CGFloat = 280,
        isSidebarEnabled: Bool = true,
        onOpenStirringComposer: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        _sidebarNavigation = sidebarNavigation
        self.sidebarWidth = sidebarWidth
        self.isSidebarEnabled = isSidebarEnabled
        self.onOpenStirringComposer = onOpenStirringComposer
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .leading) {
            content
                .offset(x: sidebarOpenOffset)
                .disabled(sidebarProgress > 0.01)

            if sidebarProgress > 0.001 {
                Color.black.opacity(0.3 * sidebarProgress)
                    .ignoresSafeArea()
                    .onTapGesture {
                        closeSidebar()
                    }
            }

            SidebarView(
                isPresented: sidebarNavigation.isSidebarPresented,
                selectedSoulerId: sidebarNavigation.selectedSoulerId,
                isSearchFocused: $isSidebarSearchFocused,
                sidebarWidth: sidebarWidth,
                onOpenSession: { session in
                    sidebarNavigation.showSession(session)
                    closeSidebar()
                },
                onOpenDraftChat: { draftTarget in
                    sidebarNavigation.showDraftChat(draftTarget)
                    closeSidebar()
                },
                onOpenStirringComposer: {
                    onOpenStirringComposer()
                    closeSidebar()
                }
            )
            .offset(x: sidebarOpenOffset - sidebarWidth)
        }
        .simultaneousGesture(sidebarGesture)
        .animation(.easeInOut(duration: 0.22), value: sidebarNavigation.isSidebarPresented)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.9), value: sidebarDragOffset)
        .onChange(of: isSidebarEnabled) { _, isEnabled in
            if !isEnabled {
                closeSidebar(animated: false)
            }
        }
    }

    private var sidebarOpenOffset: CGFloat {
        let base = sidebarNavigation.isSidebarPresented ? sidebarWidth : 0
        return min(max(base + sidebarDragOffset, 0), sidebarWidth)
    }

    private var sidebarProgress: CGFloat {
        guard sidebarWidth > 0 else { return 0 }
        return sidebarOpenOffset / sidebarWidth
    }

    private var sidebarGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                guard isSidebarEnabled else { return }
                guard isHorizontalSidebarGesture(value) else { return }

                if sidebarNavigation.isSidebarPresented {
                    sidebarDragOffset = min(0, value.translation.width)
                    return
                }

                guard canBeginOpeningSidebar(with: value) else { return }
                sidebarDragOffset = min(max(0, value.translation.width), sidebarWidth)
            }
            .onEnded { value in
                defer { sidebarDragOffset = 0 }
                guard isSidebarEnabled else { return }
                guard isHorizontalSidebarGesture(value) else { return }

                if sidebarNavigation.isSidebarPresented {
                    let predicted = sidebarWidth + value.predictedEndTranslation.width
                    let shouldOpen = predicted > sidebarWidth * 0.45

                    withAnimation(.easeInOut(duration: 0.22)) {
                        sidebarNavigation.isSidebarPresented = shouldOpen
                    }
                    return
                }

                guard canBeginOpeningSidebar(with: value) else { return }
                let shouldOpen = value.predictedEndTranslation.width > sidebarWidth * 0.28

                withAnimation(.easeInOut(duration: 0.22)) {
                    sidebarNavigation.isSidebarPresented = shouldOpen
                }
            }
    }

    private func isHorizontalSidebarGesture(_ value: DragGesture.Value) -> Bool {
        abs(value.translation.width) > abs(value.translation.height)
    }

    private func canBeginOpeningSidebar(with value: DragGesture.Value) -> Bool {
        value.startLocation.x <= sidebarEdgeActivationWidth && value.translation.width > 0
    }

    private func closeSidebar(animated: Bool = true) {
        isSidebarSearchFocused = false
        let closeAction = {
            sidebarNavigation.isSidebarPresented = false
        }
        if animated {
            withAnimation(.easeInOut(duration: 0.2), closeAction)
        } else {
            closeAction()
        }
    }
}

struct SidebarView: View {
    @Environment(\.modelContext) private var context
    @State private var authManager = AuthManager.shared
    let isPresented: Bool
    let selectedSoulerId: UUID?
    @FocusState.Binding var isSearchFocused: Bool
    let sidebarWidth: CGFloat
    let onOpenSession: (ChatSession) -> Void
    let onOpenDraftChat: (SidebarDraftChatTarget) -> Void
    let onOpenStirringComposer: () -> Void
    @State private var resonances: [Resonance] = []
    @State private var isSyncingResonances = false
    @State private var isLoadingMoreResonances = false
    @State private var hasMoreResonances = true
    @State private var resonanceMenuError: String?
    @State private var resonanceSearchText = ""

    private let resonancePageSize = 20
    private let incrementalOverlapSeconds: TimeInterval = 1

    private var currentUserId: String? {
        authManager.currentUserId?.uuidString
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if authManager.isAnonymous {
                AppleSignInPromptCard(
                    icon: "bubble.left.and.bubble.right.fill",
                    title: "anonymous.restricted.sidebar.title",
                    description: "anonymous.restricted.sidebar.description"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                if !resonances.isEmpty {
                    sidebarTopToolbar
                }

                Group {
                    if let resonanceMenuError {
                        centeredSidebarStatus {
                            Text(resonanceMenuError)
                                .font(.footnote)
                                .foregroundStyle(UITheme.secondaryText)
                                .multilineTextAlignment(.center)

                            Button("common.retry") {
                                dismissSearch()
                                Task {
                                    await loadResonances()
                                }
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
                        centeredSidebarStatus {
                            VStack(spacing: 10) {
                                ProgressView()
                                    .tint(UITheme.primaryText)

                                Text("common.loading")
                                    .font(.footnote)
                                    .foregroundStyle(UITheme.secondaryText)
                            }
                        }
                    } else if displayedResonances.isEmpty {
                        if resonances.isEmpty, !hasActiveResonanceSearch {
                            resonanceEmptyStateView
                                .padding(.top, 6)
                                .contentShape(.rect)
                                .onTapGesture(perform: dismissSearch)
                        } else {
                            if hasActiveResonanceSearch {
                                ContentUnavailableView.search(text: resonanceSearchText)
                                    .padding(.top, 6)
                                    .contentShape(.rect)
                                    .onTapGesture(perform: dismissSearch)
                            } else {
                                ContentUnavailableView {
                                    Label("resonance.empty", systemImage: "magnifyingglass")
                                }
                                .padding(.top, 6)
                                .contentShape(.rect)
                                .onTapGesture(perform: dismissSearch)
                            }
                        }
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(displayedResonances) { resonance in
                                    Button {
                                        dismissSearch()
                                        openResonance(resonance)
                                    } label: {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(resonance.soulerName)
                                                .lineLimit(1)
                                                .font(.body.weight(.medium))
                                                .fontDesign(.serif)

                                            if !resonance.lastSessionTitle.isEmpty {
                                                Text(resonance.lastSessionTitle)
                                                    .lineLimit(1)
                                                    .font(.footnote)
                                                    .foregroundStyle(UITheme.secondaryText)
                                                    .fontDesign(.serif)
                                            }
                                        }
                                        .foregroundStyle(UITheme.primaryText)
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 12)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .background(
                                            selectedSoulerId == resonance.soulerId ? .white.opacity(0.15) : .clear,
                                            in: .rect(cornerRadius: 12)
                                        )
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
                                    .padding(.top, 8)
                                } else if hasMoreResonances, !hasActiveResonanceSearch {
                                    Color.clear
                                        .frame(height: 1)
                                        .onAppear {
                                            Task {
                                                await loadMoreResonances()
                                            }
                                        }
                                }
                            }
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .contentShape(.rect)
                        .onTapGesture(perform: dismissSearch)
                        .padding(.horizontal, -12)
                        .contentMargins(.horizontal, 12, for: .scrollContent)
                        .contentMargins(.horizontal, 0, for: .scrollIndicators)
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(12)
        .frame(width: sidebarWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .environment(\.colorScheme, .dark)
                Color.black.opacity(0.4)
            }
            .ignoresSafeArea()
        }
        .task(id: authManager.currentUserId) {
            if authManager.isAnonymous || authManager.currentUserId == nil {
                resetResonanceState()
            } else {
                await loadResonances()
            }
        }
        .onChange(of: isPresented) { _, presented in
            guard presented, !authManager.isAnonymous else { return }
            Task { await loadResonances() }
        }
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

    private var resonanceEmptyStateView: some View {
        SereneContentUnavailableView(
            title: "starsea.empty.resonanceTitle",
            symbol: "bubble.left.and.bubble.right",
            subtitle: "starsea.empty.resonanceSubtitle",
            actionTitle: "starsea.action.writeStirring",
            action: onOpenStirringComposer
        )
    }

    private var sidebarTopToolbar: some View {
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
        .padding(.horizontal, 12)
        .frame(height: 44)
        .background(Color.clear, in: .capsule)
        .glassEffect(in: .capsule)
        .padding(.horizontal, 2)
    }

    private func centeredSidebarStatus<Content: View>(@ViewBuilder content: () -> Content) -> some View {
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
                stirrings: currentState.stirrings
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
                    stirrings: currentState.stirrings
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
            onOpenSession(ChatSession(
                id: sessionId,
                soulerId: resonance.soulerId,
                chapterId: nil,
                soulerName: resonance.soulerName,
                title: resonance.lastSessionTitle
            ))
        } else {
            onOpenDraftChat(draftTarget(for: resonance))
        }
    }

    private func dismissSearch() {
        isSearchFocused = false
    }

    private func draftTarget(for resonance: Resonance) -> SidebarDraftChatTarget {
        SidebarDraftChatTarget(
            soulerId: resonance.soulerId,
            soulerName: resonance.soulerName
        )
    }
}

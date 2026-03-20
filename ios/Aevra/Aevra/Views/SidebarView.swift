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
    let onOpenGlimmerComposer: () -> Void
    let content: Content

    @State private var sidebarDragOffset: CGFloat = 0
    @FocusState private var isSidebarSearchFocused: Bool
    private let sidebarEdgeActivationWidth: CGFloat = 28

    init(
        sidebarNavigation: Binding<SidebarNavigationState>,
        sidebarWidth: CGFloat = 280,
        isSidebarEnabled: Bool = true,
        onOpenGlimmerComposer: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        _sidebarNavigation = sidebarNavigation
        self.sidebarWidth = sidebarWidth
        self.isSidebarEnabled = isSidebarEnabled
        self.onOpenGlimmerComposer = onOpenGlimmerComposer
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
                onOpenGlimmerComposer: {
                    onOpenGlimmerComposer()
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
    @State private var authManager = AuthManager.shared
    let isPresented: Bool
    let selectedSoulerId: UUID?
    @FocusState.Binding var isSearchFocused: Bool
    let sidebarWidth: CGFloat
    let onOpenSession: (ChatSession) -> Void
    let onOpenDraftChat: (SidebarDraftChatTarget) -> Void
    let onOpenGlimmerComposer: () -> Void
    @State private var resonances: [Resonance] = []
    @State private var isLoadingResonances = false
    @State private var hasMoreResonances = true
    @State private var resonanceOffset = 0
    @State private var resonanceMenuError: String?
    @State private var resonanceSearchText = ""

    private let resonancePageSize = 20

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
                        VStack(alignment: .leading, spacing: 10) {
                            Text(resonanceMenuError)
                                .font(.footnote)
                                .foregroundStyle(UITheme.secondaryText)

                            Button("common.retry") {
                                dismissSearch()
                                Task {
                                    await loadResonances()
                                }
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        .padding(.top, 8)
                    } else if isLoadingResonances, resonances.isEmpty {
                        HStack(spacing: 8) {
                            ProgressView()
                            Text("common.loading")
                                .font(.footnote)
                                .foregroundStyle(UITheme.secondaryText)
                        }
                        .padding(.top, 8)
                        .contentShape(.rect)
                        .onTapGesture(perform: dismissSearch)
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

                                            Text(resonance.lastSessionTitle)
                                                .lineLimit(1)
                                                .font(.footnote)
                                                .foregroundStyle(UITheme.secondaryText)
                                                .fontDesign(.serif)
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

                                if isLoadingResonances {
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
        .background(.ultraThinMaterial)
        .task(id: authManager.isAnonymous) {
            if authManager.isAnonymous {
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
        ContentUnavailableView {
            Text("starsea.empty.resonanceTitle")
                .fontDesign(.serif)
                .padding(.bottom, 6)
        } description: {
            Text("starsea.empty.resonanceSubtitle")
                .fontDesign(.serif)
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 4)
        } actions: {
            Button(action: onOpenGlimmerComposer) {
                Label("starsea.action.writeGlimmer", systemImage: "pencil.and.scribble")
                    .font(.footnote.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
            .background(Color.clear, in: .capsule)
            .glassEffect(in: .capsule)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
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
        .shadow(color: .black.opacity(0.12), radius: 14, y: 6)
    }

    @MainActor
    private func resetResonanceState() {
        resonances = []
        isLoadingResonances = false
        hasMoreResonances = true
        resonanceOffset = 0
        resonanceMenuError = nil
        resonanceSearchText = ""
    }

    @MainActor
    private func loadResonances() async {
        if isLoadingResonances { return }

        isLoadingResonances = true
        defer { isLoadingResonances = false }

        do {
            let page = try await Resonance.getPage(limit: resonancePageSize, offset: 0)
            resonances = page
            resonanceOffset = page.count
            hasMoreResonances = page.count == resonancePageSize
            resonanceMenuError = nil
        } catch {
            resonanceMenuError = error.localizedDescription
            resonances = []
            resonanceOffset = 0
            hasMoreResonances = true
        }
    }

    @MainActor
    private func loadMoreResonances() async {
        guard !isLoadingResonances, hasMoreResonances else { return }

        isLoadingResonances = true
        defer { isLoadingResonances = false }

        do {
            let page = try await Resonance.getPage(limit: resonancePageSize, offset: resonanceOffset)
            resonances.append(contentsOf: page)
            resonanceOffset += page.count
            hasMoreResonances = page.count == resonancePageSize
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
                soulerName: resonance.soulerName,
                title: resonance.lastSessionTitle,
                createdAt: resonance.createdAt,
                updatedAt: resonance.updatedAt
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

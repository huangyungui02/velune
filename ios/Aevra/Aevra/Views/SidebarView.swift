import SwiftUI

struct SidebarNavigationState {
    var isSidebarPresented = false
    var activeSession: ChatSession?

    var selectedSoulerId: UUID? {
        activeSession?.soulerId
    }

    var isStarSeaDestination: Bool {
        activeSession == nil
    }
}

struct SidebarContainer<Content: View>: View {
    @Binding var sidebarNavigation: SidebarNavigationState
    let sidebarWidth: CGFloat
    let onOpenGlimmerComposer: () -> Void
    let content: Content

    @State private var sidebarDragOffset: CGFloat = 0
    private let sidebarEdgeActivationWidth: CGFloat = 28

    init(
        sidebarNavigation: Binding<SidebarNavigationState>,
        sidebarWidth: CGFloat = 320,
        onOpenGlimmerComposer: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        _sidebarNavigation = sidebarNavigation
        self.sidebarWidth = sidebarWidth
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
                selectedSoulerId: sidebarNavigation.selectedSoulerId,
                sidebarWidth: sidebarWidth,
                onOpenSession: { session in
                    sidebarNavigation.activeSession = session
                    closeSidebar()
                },
                onTapStarSea: {
                    sidebarNavigation.activeSession = nil
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

    private func closeSidebar() {
        withAnimation(.easeInOut(duration: 0.2)) {
            sidebarNavigation.isSidebarPresented = false
        }
    }
}

struct SidebarView: View {
    @State private var authManager = AuthManager.shared
    let selectedSoulerId: UUID?
    let sidebarWidth: CGFloat
    let onOpenSession: (ChatSession) -> Void
    let onTapStarSea: () -> Void
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
                    } else if displayedResonances.isEmpty {
                        if resonances.isEmpty, !hasActiveResonanceSearch {
                            resonanceEmptyStateView
                                .padding(.top, 6)
                        } else {
                            if hasActiveResonanceSearch {
                                ContentUnavailableView.search(text: resonanceSearchText)
                                    .padding(.top, 6)
                            } else {
                                ContentUnavailableView {
                                    Label("resonance.empty", systemImage: "magnifyingglass")
                                }
                                .padding(.top, 6)
                            }
                        }
                    } else {
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 4) {
                                ForEach(displayedResonances) { resonance in
                                    Button {
                                        Task {
                                            await openLatestSession(for: resonance)
                                        }
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
            Label("starsea.empty.resonanceTitle", systemImage: "sparkles")
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
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(UITheme.secondaryText)

                TextField("common.search", text: $resonanceSearchText)
                    .textFieldStyle(.plain)
                    .font(.footnote)
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText)
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(Color.clear, in: .capsule)
            .glassEffect(in: .capsule)

            Button(action: onTapStarSea) {
                Image(systemName: "sparkles")
                    .font(.headline.weight(.semibold))
                    .frame(width: 46, height: 46)
                    .background(Color.clear, in: .circle)
                    .glassEffect(in: .circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(UITheme.primaryText)
        }
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

    @MainActor
    private func openLatestSession(for resonance: Resonance) async {
        do {
            if let lastSessionId = resonance.lastSessionId,
               let session = try await ChatSession.get(id: lastSessionId)
            {
                resonanceMenuError = nil
                onOpenSession(session)
                return
            }

            guard let session = try await ChatSession.getLatest(soulerId: resonance.soulerId) else {
                resonanceMenuError = String(localized: "resonance.empty")
                return
            }

            resonanceMenuError = nil
            onOpenSession(session)
        } catch {
            resonanceMenuError = error.localizedDescription
        }
    }
}

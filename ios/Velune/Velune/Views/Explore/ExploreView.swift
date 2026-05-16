import SwiftUI

private enum ExploreTab: String, CaseIterable, Identifiable {
    case featured
    case latest

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .featured:
            return "explore.tab.featured"
        case .latest:
            return "explore.tab.latest"
        }
    }
}

struct ExploreView: View {
    @FocusState private var isSearchFocused: Bool
    @State private var selectedTab: ExploreTab = .featured
    @State private var featuredSections: [ExploreSection] = []
    @State private var latestItems: [ExploreSoulerItem] = []
    @State private var searchResults: [ExploreSoulerItem] = []
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var latestPage = 0
    @State private var latestHasMore = true
    @State private var isLoadingFeatured = false
    @State private var isLoadingLatest = false
    @State private var isLoadingMoreLatest = false
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var searchErrorMessage: String?
    
    @Namespace private var tabNamespace

    private let gridColumns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
    ]

    private var normalizedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasActiveSearch: Bool {
        !normalizedSearchText.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()

                VStack(spacing: 0) {
                    ExploreHeaderView(
                        searchText: $searchText,
                        isSearchFocused: $isSearchFocused,
                        selectedTab: $selectedTab,
                        hasActiveSearch: hasActiveSearch,
                        tabNamespace: tabNamespace,
                        onClearSearch: clearSearch
                    )
                    
                    if hasActiveSearch {
                        ExploreSearchContent(
                            query: normalizedSearchText,
                            items: searchResults,
                            isLoading: isSearching,
                            errorMessage: searchErrorMessage,
                            gridColumns: gridColumns,
                            onRetry: scheduleSearch,
                            onSelect: dismissSearch
                        )
                    } else {
                        ExploreMainContent(
                            selectedTab: selectedTab,
                            featuredSections: featuredSections,
                            latestItems: latestItems,
                            latestHasMore: latestHasMore,
                            isLoadingFeatured: isLoadingFeatured,
                            isLoadingLatest: isLoadingLatest,
                            isLoadingMoreLatest: isLoadingMoreLatest,
                            errorMessage: errorMessage,
                            gridColumns: gridColumns,
                            onRefresh: refreshCurrentTab,
                            onLoadMoreLatest: loadMoreLatest
                        )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await loadFeaturedIfNeeded()
            }
            .onChange(of: selectedTab) { _, tab in
                guard tab == .latest else { return }
                Task { await loadLatestIfNeeded() }
            }
            .onChange(of: searchText) { _, _ in
                scheduleSearch()
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    @MainActor
    private func loadFeaturedIfNeeded() async {
        guard featuredSections.isEmpty else { return }
        await loadFeatured()
    }

    @MainActor
    private func loadLatestIfNeeded() async {
        guard latestItems.isEmpty else { return }
        await loadLatest(reset: true)
    }

    private func refreshCurrentTab() {
        Task {
            if selectedTab == .featured {
                await loadFeatured()
            } else {
                await loadLatest(reset: true)
            }
        }
    }

    @MainActor
    private func loadFeatured() async {
        if isLoadingFeatured { return }
        isLoadingFeatured = true
        errorMessage = nil
        defer { isLoadingFeatured = false }

        do {
            featuredSections = try await ExploreSection.featured()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadMoreLatest() {
        Task { await loadLatest(reset: false) }
    }

    @MainActor
    private func loadLatest(reset: Bool) async {
        if isLoadingLatest || isLoadingMoreLatest { return }
        if !reset, !latestHasMore { return }

        if reset {
            isLoadingLatest = true
            latestPage = 0
            latestHasMore = true
        } else {
            isLoadingMoreLatest = true
        }
        errorMessage = nil
        defer {
            isLoadingLatest = false
            isLoadingMoreLatest = false
        }

        do {
            let page = try await ExploreSoulerItem.latest(page: latestPage + 1)
            latestPage = page.page
            latestHasMore = page.hasNextPage
            latestItems = reset ? page.items : latestItems + page.items
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = normalizedSearchText
        guard !query.isEmpty else {
            searchResults = []
            searchErrorMessage = nil
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(260))
            guard !Task.isCancelled else { return }
            await search(query)
        }
    }

    @MainActor
    private func search(_ query: String) async {
        isSearching = true
        searchErrorMessage = nil
        defer { isSearching = false }

        do {
            searchResults = try await ExploreSoulerItem.search(query: query)
        } catch {
            searchErrorMessage = error.localizedDescription
        }
    }

    private func clearSearch() {
        searchText = ""
        dismissSearch()
    }

    private func dismissSearch() {
        isSearchFocused = false
    }
}

private struct ExploreHeaderView: View {
    @Binding var searchText: String
    var isSearchFocused: FocusState<Bool>.Binding
    @Binding var selectedTab: ExploreTab
    let hasActiveSearch: Bool
    let tabNamespace: Namespace.ID
    let onClearSearch: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            ExploreSearchField(
                text: $searchText,
                isFocused: isSearchFocused,
                onClear: onClearSearch
            )
            .padding(.horizontal, 20)

            if !hasActiveSearch {
                HStack(spacing: 32) {
                    ForEach(ExploreTab.allCases) { tab in
                        Button(action: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                selectedTab = tab
                            }
                        }) {
                            VStack(spacing: 6) {
                                Text(tab.titleKey)
                                    .font(.title3)
                                    .fontWeight(selectedTab == tab ? .semibold : .medium)
                                    .fontDesign(.serif)
                                    .foregroundStyle(selectedTab == tab ? UITheme.primaryText : UITheme.secondaryText)
                                
                                if selectedTab == tab {
                                    Capsule()
                                        .fill(UITheme.primaryText)
                                        .frame(width: 24, height: 2)
                                        .matchedGeometryEffect(id: "TabIndicator", in: tabNamespace)
                                } else {
                                    Color.clear
                                        .frame(width: 24, height: 2)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
            }
        }
        .padding(.top, 16)
        .padding(.bottom, 8)
    }
}

private struct ExploreSearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(UITheme.secondaryText)

            TextField("explore.search.placeholder", text: $text)
                .focused(isFocused)
                .submitLabel(.search)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 15))
                        .foregroundStyle(UITheme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .glassEffect(in: .capsule)
    }
}

private struct ExploreMainContent: View {
    let selectedTab: ExploreTab
    let featuredSections: [ExploreSection]
    let latestItems: [ExploreSoulerItem]
    let latestHasMore: Bool
    let isLoadingFeatured: Bool
    let isLoadingLatest: Bool
    let isLoadingMoreLatest: Bool
    let errorMessage: String?
    let gridColumns: [GridItem]
    let onRefresh: () -> Void
    let onLoadMoreLatest: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if let errorMessage {
                    RetryStateView(message: errorMessage, onRetry: onRefresh)
                        .padding(.horizontal, 20)
                } else if selectedTab == .featured {
                    FeaturedSectionsView(
                        sections: featuredSections,
                        isLoading: isLoadingFeatured
                    )
                } else {
                    LatestSoulersView(
                        items: latestItems,
                        hasMore: latestHasMore,
                        isLoading: isLoadingLatest,
                        isLoadingMore: isLoadingMoreLatest,
                        gridColumns: gridColumns,
                        onLoadMore: onLoadMoreLatest
                    )
                }
            }
            .padding(.vertical, 24)
        }
        .refreshable {
            onRefresh()
        }
    }
}

private struct ExploreSearchContent: View {
    let query: String
    let items: [ExploreSoulerItem]
    let isLoading: Bool
    let errorMessage: String?
    let gridColumns: [GridItem]
    let onRetry: () -> Void
    let onSelect: () -> Void

    var body: some View {
        ScrollView {
            if let errorMessage {
                RetryStateView(message: errorMessage, onRetry: onRetry)
                    .padding(.top, 120)
            } else if isLoading {
                SoulerBookSkeletonGrid(columns: gridColumns)
                    .padding(.top, 24)
            } else if items.isEmpty {
                ContentUnavailableView.search(text: query)
                    .padding(.top, 120)
            } else {
                LazyVGrid(columns: gridColumns, spacing: 24) {
                    ForEach(items) { item in
                        NavigationLink {
                            SoulerView(soulerId: item.id)
                        } label: {
                            SoulerBookCoverView(name: item.name, imageURL: item.imageURL)
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(TapGesture().onEnded(onSelect))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }
}

private struct FeaturedSectionsView: View {
    let sections: [ExploreSection]
    let isLoading: Bool

    var body: some View {
        if isLoading && sections.isEmpty {
            VStack(alignment: .leading, spacing: 32) {
                ForEach(0 ..< 2, id: \.self) { _ in
                    FeaturedSectionSkeleton()
                }
            }
        } else if sections.isEmpty {
            SereneContentUnavailableView(
                title: "explore.empty.featured",
                symbol: "safari",
                actionTitle: "common.refresh",
                actionIcon: "arrow.clockwise"
            )
            .padding(.horizontal, 20)
        } else {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.title3.weight(.medium))
                            .fontDesign(.serif)
                            .foregroundStyle(UITheme.primaryText)

                        if !section.subtitle.isEmpty {
                            Text(section.subtitle)
                                .font(.footnote)
                                .foregroundStyle(UITheme.secondaryText)
                        }
                    }
                    .padding(.horizontal, 20)

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 16) {
                            ForEach(section.soulers) { souler in
                                NavigationLink {
                                    SoulerView(soulerId: souler.id)
                                } label: {
                                    SoulerBookCoverView(name: souler.name, imageURL: souler.imageURL)
                                        .frame(width: 130)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .scrollTargetLayout()
                    }
                    .contentMargins(.horizontal, 20, for: .scrollContent)
                    .scrollTargetBehavior(.viewAligned)
                }
            }
        }
    }
}

private struct LatestSoulersView: View {
    let items: [ExploreSoulerItem]
    let hasMore: Bool
    let isLoading: Bool
    let isLoadingMore: Bool
    let gridColumns: [GridItem]
    let onLoadMore: () -> Void

    var body: some View {
        if isLoading && items.isEmpty {
            SoulerBookSkeletonGrid(columns: gridColumns)
        } else if items.isEmpty {
            SereneContentUnavailableView(
                title: "explore.empty.latest",
                symbol: "clock",
                actionTitle: "common.refresh",
                actionIcon: "arrow.clockwise"
            )
            .padding(.horizontal, 20)
        } else {
            LazyVGrid(columns: gridColumns, spacing: 24) {
                ForEach(items) { item in
                    NavigationLink {
                        SoulerView(soulerId: item.id)
                    } label: {
                        SoulerBookCoverView(name: item.name, imageURL: item.imageURL)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 20)

            if isLoadingMore {
                ProgressView()
                    .tint(UITheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            } else if hasMore {
                Color.clear
                    .frame(height: 1)
                    .onAppear(perform: onLoadMore)
            }
        }
    }
}

private struct RetryStateView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text(message)
                .font(.footnote)
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.center)

            Button("common.retry", action: onRetry)
                .buttonStyle(.bordered)
                .tint(UITheme.primaryText)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct FeaturedSectionSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(.white.opacity(0.12))
                    .frame(width: 120, height: 24)
            }
            .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(0 ..< 4, id: \.self) { _ in
                        SoulerBookCoverView(name: "      ", imageURL: nil)
                            .frame(width: 130)
                    }
                }
            }
            .contentMargins(.horizontal, 20, for: .scrollContent)
            .disabled(true)
        }
        .redacted(reason: .placeholder)
    }
}

private struct SoulerBookSkeletonGrid: View {
    let columns: [GridItem]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(0 ..< 9, id: \.self) { _ in
                SoulerBookCoverView(name: "      ", imageURL: nil)
            }
        }
        .redacted(reason: .placeholder)
        .padding(.horizontal, 20)
    }
}

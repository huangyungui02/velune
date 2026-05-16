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

                VStack(spacing: 12) {
                    ExploreSearchField(
                        text: $searchText,
                        isFocused: $isSearchFocused,
                        onClear: clearSearch
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)

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
                            selectedTab: $selectedTab,
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
            .navigationTitle("explore.title")
            .navigationBarTitleDisplayMode(.inline)
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

private struct ExploreSearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(UITheme.secondaryText)

            TextField("explore.search.placeholder", text: $text)
                .focused(isFocused)
                .submitLabel(.search)
                .textFieldStyle(.plain)
                .font(.footnote)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)

            if !text.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(UITheme.tertiaryText)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .glassEffect(in: .capsule)
    }
}

private struct ExploreMainContent: View {
    @Binding var selectedTab: ExploreTab
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
        VStack(spacing: 12) {
            Picker("explore.title", selection: $selectedTab) {
                ForEach(ExploreTab.allCases) { tab in
                    Text(tab.titleKey).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let errorMessage {
                        RetryStateView(message: errorMessage, onRetry: onRefresh)
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
                .padding(.horizontal, 20)
                .padding(.bottom, 24)
            }
            .refreshable {
                onRefresh()
            }
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
                    .padding(.horizontal, 16)
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
                .padding(.bottom, 24)
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
            VStack(alignment: .leading, spacing: 18) {
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
        } else {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 14) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(section.title)
                            .font(.headline.weight(.semibold))
                            .fontDesign(.serif)
                            .foregroundStyle(UITheme.primaryText)

                        if !section.subtitle.isEmpty {
                            Text(section.subtitle)
                                .font(.footnote)
                                .foregroundStyle(UITheme.secondaryText)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 20) {
                            ForEach(section.soulers) { souler in
                                NavigationLink {
                                    SoulerView(soulerId: souler.id)
                                } label: {
                                    SoulerBookCoverView(name: souler.name, imageURL: souler.imageURL)
                                        .frame(width: 120)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .scrollTargetLayout()
                    }
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
        VStack(alignment: .leading, spacing: 12) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.white.opacity(0.12))
                .frame(width: 140, height: 20)

            HStack(spacing: 20) {
                ForEach(0 ..< 3, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.06))
                        .aspectRatio(2 / 3, contentMode: .fit)
                        .frame(width: 120)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

private struct SoulerBookSkeletonGrid: View {
    let columns: [GridItem]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 24) {
            ForEach(0 ..< 9, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 10)
                    .fill(.white.opacity(0.06))
                    .aspectRatio(2 / 3, contentMode: .fit)
            }
        }
        .redacted(reason: .placeholder)
    }
}

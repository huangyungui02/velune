import OSLog
import SwiftData
import SwiftUI

enum ReadingTab: String, CaseIterable, Identifiable {
    case featured
    case latest
    case bookshelf

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .featured:
            return "reading.tab.featured"
        case .latest:
            return "reading.tab.latest"
        case .bookshelf:
            return "reading.tab.bookshelf"
        }
    }
}

struct ReadingView: View {
    @Environment(\.modelContext) private var context
    @FocusState private var isSearchFocused: Bool
    @State private var selectedTab: ReadingTab = .featured
    @State private var authManager = AuthManager.shared
    @State private var featuredSections: [ReadingSection] = []
    @State private var latestItems: [ReadingSoulerItem] = []
    @State private var bookshelfItems: [BookshelfItem] = []
    @State private var searchResults: [ReadingSoulerItem] = []
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var latestPage = 0
    @State private var latestHasMore = true
    @State private var isLoadingFeatured = false
    @State private var isLoadingLatest = false
    @State private var isLoadingMoreLatest = false
    @State private var isLoadingBookshelf = false
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var bookshelfErrorMessage: String?
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

    private var visibleErrorMessage: String? {
        guard let errorMessage else { return nil }

        if selectedTab == .featured, !featuredSections.isEmpty {
            return nil
        }
        if selectedTab == .latest, !latestItems.isEmpty {
            return nil
        }
        if selectedTab == .bookshelf, !bookshelfItems.isEmpty {
            return nil
        }
        return errorMessage
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()

                VStack(spacing: 0) {
                    ReadingHeaderView(
                        searchText: $searchText,
                        isSearchFocused: $isSearchFocused,
                        selectedTab: $selectedTab,
                        hasActiveSearch: hasActiveSearch,
                        tabNamespace: tabNamespace,
                        onClearSearch: clearSearch
                    )
                    
                    if hasActiveSearch {
                        ReadingSearchContent(
                            query: normalizedSearchText,
                            items: searchResults,
                            isLoading: isSearching,
                            errorMessage: searchErrorMessage,
                            gridColumns: gridColumns,
                            onRetry: scheduleSearch,
                            onSelect: dismissSearch
                        )
                    } else {
                        ReadingMainContent(
                            selectedTab: selectedTab,
                            featuredSections: featuredSections,
                            latestItems: latestItems,
                            bookshelfItems: bookshelfItems,
                            latestHasMore: latestHasMore,
                            isLoadingFeatured: isLoadingFeatured,
                            isLoadingLatest: isLoadingLatest,
                            isLoadingMoreLatest: isLoadingMoreLatest,
                            isLoadingBookshelf: isLoadingBookshelf,
                            errorMessage: visibleErrorMessage,
                            bookshelfErrorMessage: bookshelfErrorMessage,
                            gridColumns: gridColumns,
                            onRefresh: refreshCurrentTab,
                            onRetryBookshelf: refreshBookshelf,
                            onLoadMoreLatest: loadMoreLatest
                        )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task {
                await loadCachedReadingThenRefresh()
            }
            .onChange(of: selectedTab) { _, tab in
                Task {
                    switch tab {
                    case .featured:
                        break
                    case .latest:
                        await loadLatestIfNeeded()
                    case .bookshelf:
                        await loadBookshelf()
                    }
                }
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
    private func loadCachedReadingThenRefresh() async {
        await loadCachedReading()

        if selectedTab == .featured {
            await loadFeatured()
        } else if selectedTab == .latest {
            await loadLatest(reset: true)
        } else {
            await loadBookshelf()
        }
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
            } else if selectedTab == .latest {
                await loadLatest(reset: true)
            } else {
                await loadBookshelf()
            }
        }
    }

    private func refreshBookshelf() {
        Task { await loadBookshelf() }
    }

    @MainActor
    private func loadFeatured() async {
        if isLoadingFeatured { return }
        isLoadingFeatured = true
        errorMessage = nil
        defer { isLoadingFeatured = false }

        do {
            featuredSections = try await ReadingSection.featured()
            saveReadingCache()
        } catch {
            handleRefreshFailure(error)
        }
    }

    private func loadMoreLatest() {
        Task { await loadLatest(reset: false) }
    }

    @MainActor
    private func loadBookshelf() async {
        if isLoadingBookshelf { return }

        guard let userId = authManager.currentUserId?.uuidString else {
            bookshelfItems = []
            bookshelfErrorMessage = nil
            return
        }

        let hasLocalCache = loadLocalBookshelf(userId: userId)
        isLoadingBookshelf = !hasLocalCache
        bookshelfErrorMessage = nil
        defer { isLoadingBookshelf = false }

        do {
            let remoteItems = try await BookshelfItem.fetch()
            let hasChanges = try BookshelfItem.mergeCached(remoteItems, userId: userId, context: context)
            if hasChanges || bookshelfItems.isEmpty {
                bookshelfItems = try BookshelfItem.fetchCached(userId: userId, context: context)
            }
        } catch {
            if !hasLocalCache && bookshelfItems.isEmpty {
                bookshelfErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    @discardableResult
    private func loadLocalBookshelf(userId: String) -> Bool {
        do {
            bookshelfItems = try BookshelfItem.fetchCached(userId: userId, context: context)
            if !bookshelfItems.isEmpty {
                bookshelfErrorMessage = nil
            }
            return !bookshelfItems.isEmpty
        } catch {
            bookshelfItems = []
            return false
        }
    }

    @MainActor
    private func loadLatest(reset: Bool) async {
        if isLoadingLatest || isLoadingMoreLatest { return }
        if !reset, !latestHasMore { return }

        let previousItems = latestItems
        let previousPage = latestPage
        let previousHasMore = latestHasMore

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
            let page = try await ReadingSoulerItem.latest(page: latestPage + 1)
            latestPage = page.page
            latestHasMore = page.hasNextPage
            latestItems = reset ? page.items : latestItems + page.items
            saveReadingCache()
        } catch {
            if reset {
                latestItems = previousItems
                latestPage = previousPage
                latestHasMore = previousHasMore
            }
            handleRefreshFailure(error)
        }
    }

    @MainActor
    private func loadCachedReading() async {
        do {
            guard let payload = try ReadingCacheStore.shared.load() else { return }
            featuredSections = payload.featuredSections
            latestItems = payload.latestItems
            latestPage = payload.latestPage
            latestHasMore = payload.latestHasMore
            errorMessage = nil
        } catch {
            AppLogger.storage.debug("Failed to load Reading cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func handleRefreshFailure(_ error: Error) {
        if featuredSections.isEmpty && latestItems.isEmpty {
            errorMessage = error.localizedDescription
        } else {
            errorMessage = nil
        }
    }

    @MainActor
    private func saveReadingCache() {
        let payload = CachedReadingPayload(
            savedAt: Date(),
            featuredSections: featuredSections,
            latestItems: latestItems,
            latestPage: latestPage,
            latestHasMore: latestHasMore
        )

        Task {
            do {
                try ReadingCacheStore.shared.save(payload)
            } catch {
                AppLogger.storage.debug("Failed to save Reading cache: \(error.localizedDescription, privacy: .public)")
            }
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
            searchResults = try await ReadingSoulerItem.search(query: query)
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

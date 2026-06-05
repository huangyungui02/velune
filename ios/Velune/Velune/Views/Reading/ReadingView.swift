import OSLog
import SwiftUI

enum ReadingTab: String, CaseIterable, Identifiable {
    case featured
    case bookshelf

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .featured:
            return "reading.tab.featured"
        case .bookshelf:
            return "reading.tab.bookshelf"
        }
    }
}

struct ReadingView: View {
    @Environment(\.locale) private var locale
    @FocusState private var isSearchFocused: Bool
    @State private var selectedTab: ReadingTab = .featured
    @State private var authManager = AuthManager.shared
    @State private var featuredSections: [ReadingSection] = []
    @State private var bookshelfItems: [BookshelfItem] = []
    @State private var searchResults: [ReadingSoulerItem] = []
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var isLoadingFeatured = false
    @State private var isLoadingBookshelf = false
    @State private var isSearching = false
    @State private var errorMessage: String?
    @State private var bookshelfErrorMessage: String?
    @State private var searchErrorMessage: String?
    @State private var displayedLanguageCode = AppLanguage.current.apiLanguageCode
    
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
        if selectedTab == .bookshelf, !bookshelfItems.isEmpty {
            return nil
        }
        return errorMessage
    }

    private var currentLanguageCode: String {
        AppLanguage.current.apiLanguageCode
    }

    private var languageRefreshKey: String {
        "\(locale.identifier)-\(currentLanguageCode)"
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
                            bookshelfItems: bookshelfItems,
                            isLoadingFeatured: isLoadingFeatured,
                            isLoadingBookshelf: isLoadingBookshelf,
                            errorMessage: visibleErrorMessage,
                            bookshelfErrorMessage: bookshelfErrorMessage,
                            gridColumns: gridColumns,
                            onRefresh: refreshCurrentTab,
                            onRetryBookshelf: refreshBookshelf
                        )
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
            .task(id: languageRefreshKey) {
                await loadCachedReadingThenRefresh()
            }
            .onChange(of: selectedTab) { _, tab in
                Task {
                    switch tab {
                    case .featured:
                        break
                    case .bookshelf:
                        await loadBookshelf()
                    }
                }
            }
            .onChange(of: searchText) { _, _ in
                scheduleSearch()
            }
            .onReceive(NotificationCenter.default.publisher(for: .bookselfDidChange)) { _ in
                guard selectedTab == .bookshelf else { return }
                refreshBookshelf()
            }
            .onDisappear {
                searchTask?.cancel()
            }
        }
    }

    @MainActor
    private func loadCachedReadingThenRefresh() async {
        resetLanguageScopedStateIfNeeded()
        await loadCachedReading()

        if selectedTab == .featured {
            await loadFeatured()
        } else {
            await loadBookshelf()
        }
    }

    @MainActor
    private func resetLanguageScopedStateIfNeeded() {
        guard displayedLanguageCode != currentLanguageCode else { return }

        displayedLanguageCode = currentLanguageCode
        featuredSections = []
        searchResults = []
        searchText = ""
        errorMessage = nil
        searchErrorMessage = nil
        searchTask?.cancel()
    }

    private func refreshCurrentTab() {
        Task {
            if selectedTab == .featured {
                await loadFeatured()
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

    @MainActor
    private func loadBookshelf() async {
        if isLoadingBookshelf { return }

        guard authManager.currentUserId != nil else {
            bookshelfItems = []
            bookshelfErrorMessage = nil
            return
        }

        isLoadingBookshelf = bookshelfItems.isEmpty
        bookshelfErrorMessage = nil
        defer { isLoadingBookshelf = false }

        do {
            bookshelfItems = try await BookshelfItem.fetch()
        } catch {
            if bookshelfItems.isEmpty {
                bookshelfErrorMessage = error.localizedDescription
            }
        }
    }

    @MainActor
    private func loadCachedReading() async {
        do {
            guard let payload = try ReadingCacheStore.shared.load() else { return }
            guard payload.languageCode == currentLanguageCode else { return }
            featuredSections = payload.featuredSections
            errorMessage = nil
        } catch {
            AppLogger.storage.debug("Failed to load Reading cache: \(error.localizedDescription, privacy: .public)")
        }
    }

    @MainActor
    private func handleRefreshFailure(_ error: Error) {
        if featuredSections.isEmpty {
            errorMessage = error.localizedDescription
        } else {
            errorMessage = nil
        }
    }

    @MainActor
    private func saveReadingCache() {
        let payload = CachedReadingPayload(
            savedAt: Date(),
            languageCode: currentLanguageCode,
            featuredSections: featuredSections
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

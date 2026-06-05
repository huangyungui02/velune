import SwiftUI

struct ReadingMainContent: View {
    let selectedTab: ReadingTab
    let featuredSections: [ReadingSection]
    let bookshelfItems: [BookshelfItem]
    let isLoadingFeatured: Bool
    let isLoadingBookshelf: Bool
    let errorMessage: String?
    let bookshelfErrorMessage: String?
    let gridColumns: [GridItem]
    let onRefresh: () -> Void
    let onRetryBookshelf: () -> Void

    var body: some View {
        if selectedTab == .bookshelf {
            scrollContent
        } else {
            scrollContent
                .refreshable {
                    onRefresh()
                }
        }
    }

    private var scrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                if let errorMessage {
                    ReadingRetryStateView(message: errorMessage, onRetry: onRefresh)
                        .padding(.horizontal, 20)
                } else if selectedTab == .featured {
                    ReadingFeaturedSectionsView(
                        sections: featuredSections,
                        isLoading: isLoadingFeatured
                    )
                } else {
                    ReadingBookshelfContent(
                        items: bookshelfItems,
                        isLoading: isLoadingBookshelf,
                        errorMessage: bookshelfErrorMessage,
                        gridColumns: gridColumns,
                        onRetry: onRetryBookshelf
                    )
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 24)
        }
    }
}

struct ReadingSearchContent: View {
    let query: String
    let items: [ReadingSoulerItem]
    let isLoading: Bool
    let errorMessage: String?
    let gridColumns: [GridItem]
    let onRetry: () -> Void
    let onSelect: () -> Void

    var body: some View {
        ScrollView {
            if let errorMessage {
                ReadingRetryStateView(message: errorMessage, onRetry: onRetry)
                    .padding(.top, 120)
            } else if isLoading {
                ReadingSoulerBookSkeletonGrid(columns: gridColumns)
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

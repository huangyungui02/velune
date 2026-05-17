import SwiftUI

struct ReadingFeaturedSectionsView: View {
    let sections: [ReadingSection]
    let isLoading: Bool

    var body: some View {
        if isLoading && sections.isEmpty {
            VStack(alignment: .leading, spacing: 32) {
                ForEach(0 ..< 2, id: \.self) { _ in
                    ReadingFeaturedSectionSkeleton()
                }
            }
        } else if sections.isEmpty {
            SereneContentUnavailableView(
                title: "reading.empty.featured",
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

struct ReadingLatestSoulersView: View {
    let items: [ReadingSoulerItem]
    let hasMore: Bool
    let isLoading: Bool
    let isLoadingMore: Bool
    let gridColumns: [GridItem]
    let onLoadMore: () -> Void

    var body: some View {
        if isLoading && items.isEmpty {
            ReadingSoulerBookSkeletonGrid(columns: gridColumns)
        } else if items.isEmpty {
            SereneContentUnavailableView(
                title: "reading.empty.latest",
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

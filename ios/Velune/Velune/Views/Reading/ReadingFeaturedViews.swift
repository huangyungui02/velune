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
            ContentUnavailableView(
                "reading.empty.featured",
                systemImage: "safari"
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

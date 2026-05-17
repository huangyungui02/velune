import SwiftUI

struct ReadingRetryStateView: View {
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

struct ReadingFeaturedSectionSkeleton: View {
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

struct ReadingSoulerBookSkeletonGrid: View {
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

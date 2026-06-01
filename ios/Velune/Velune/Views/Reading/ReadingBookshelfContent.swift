import SwiftUI

struct ReadingBookshelfContent: View {
    let items: [BookshelfItem]
    let isLoading: Bool
    let errorMessage: String?
    let gridColumns: [GridItem]
    let onRetry: () -> Void

    var body: some View {
        if let errorMessage {
            VStack(spacing: 12) {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(UITheme.secondaryText)
                    .multilineTextAlignment(.center)

                Button("common.retry", action: onRetry)
                    .buttonStyle(.bordered)
                    .tint(UITheme.primaryText)
            }
            .frame(maxWidth: .infinity, minHeight: 260)
        } else if isLoading && items.isEmpty {
            LazyVGrid(columns: gridColumns, spacing: 20) {
                ForEach(0 ..< 9, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(.white.opacity(0.06))
                        .aspectRatio(2 / 3, contentMode: .fit)
                }
            }
            .redacted(reason: .placeholder)
        } else if items.isEmpty {
            ContentUnavailableView(
                "reading.empty.bookshelf",
                systemImage: "books.vertical"
            )
            .frame(minHeight: 320)
        } else {
            LazyVGrid(columns: gridColumns, spacing: 24) {
                ForEach(items) { item in
                    NavigationLink {
                        ChatView(
                            sessionId: item.lastSessionId,
                            soulerId: item.soulerId,
                            soulerName: item.soulerName,
                            focusComposerOnAppear: false
                        )
                    } label: {
                        SoulerBookCoverView(name: item.soulerName, imageURL: item.imageURL)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

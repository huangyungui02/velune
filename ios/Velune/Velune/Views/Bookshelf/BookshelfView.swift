import SwiftUI

struct BookshelfView: View {
    @State private var items: [BookshelfItem] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    private let gridColumns = [
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
        GridItem(.flexible(), spacing: 20),
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundView()

                ScrollView {
                    BookshelfContent(
                        items: items,
                        isLoading: isLoading,
                        errorMessage: errorMessage,
                        gridColumns: gridColumns,
                        onRetry: refresh
                    )
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                    .padding(.bottom, 24)
                }
                .refreshable {
                    await loadBookshelf()
                }
            }
            .navigationTitle("bookshelf.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: refresh) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isLoading)
                }
            }
            .task {
                await loadBookshelf()
            }
        }
    }

    private func refresh() {
        Task { await loadBookshelf() }
    }

    @MainActor
    private func loadBookshelf() async {
        if isLoading { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            items = try await BookshelfItem.fetch()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct BookshelfContent: View {
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
            SereneContentUnavailableView(
                title: "bookshelf.empty",
                symbol: "books.vertical",
                actionTitle: "common.refresh",
                actionIcon: "arrow.clockwise",
                action: onRetry
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

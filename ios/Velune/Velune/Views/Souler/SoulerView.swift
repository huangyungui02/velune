import SwiftUI

struct SoulerView: View {
    let soulerId: UUID

    @State private var souler: Souler?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var feedbackSouler: Souler?
    @State private var feedbackMessage: String?
    @State private var isBookmarked = false
    @State private var isBookmarking = false
    @State private var bookmarkErrorMessage: String?

    var body: some View {
        ZStack {
            BackgroundView()

            ScrollView {
                SoulerContent(
                    souler: souler,
                    isLoading: isLoading,
                    errorMessage: errorMessage,
                    onRetry: reload
                )
                .padding(.horizontal, 20)
                .padding(.top, 20)
                .padding(.bottom, 28)
            }
            .refreshable {
                await loadSouler()
            }
        }
        .navigationTitle(souler?.name ?? "")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .toolbar {
            if let souler {
                ToolbarItem(placement: .topBarTrailing) {
                    SoulerActionMenu {
                        feedbackSouler = souler
                    }
                }

                if souler.checked {
                    ToolbarItem(placement: .bottomBar) {
                        Button {
                            toggleBookmark()
                        } label: {
                            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        }
                        .disabled(isBookmarking)
                        .accessibilityLabel(Text("souler.action.favorite"))
                    }

                    ToolbarSpacer(.flexible, placement: .bottomBar)

                    ToolbarItem(placement: .bottomBar) {
                        NavigationLink {
                            ChatView(
                                sessionId: nil,
                                soulerId: souler.id,
                                soulerName: souler.name,
                                focusComposerOnAppear: false
                            )
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: "list.bullet")
                                Text("souler.action.showFolios")
                            }
                            .padding(.horizontal, 8)
                            .fixedSize(horizontal: true, vertical: false)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("souler.action.showFolios"))
                    }
                }
            }
        }
        .sheet(item: $feedbackSouler) { souler in
            FeedbackForm(
                title: "souler.feedback.title",
                prompt: "souler.feedback.prompt",
                placeholder: "settings.feedback.placeholder",
                headerName: souler.name,
                headerImageURL: souler.imageURL,
                onSubmit: { content in
                    try await SoulerFeedback.submit(soulerId: souler.id, content: content)
                },
                onSubmitted: {
                    feedbackMessage = String(localized: "souler.feedback.submitted")
                }
            )
        }
        .alert("souler.feedback.title", isPresented: Binding(
            get: { feedbackMessage != nil },
            set: { if !$0 { feedbackMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(feedbackMessage ?? "")
        }
        .alert("souler.action.favorite", isPresented: Binding(
            get: { bookmarkErrorMessage != nil },
            set: { if !$0 { bookmarkErrorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(bookmarkErrorMessage ?? "")
        }
        .task(id: soulerId) {
            await loadSouler()
        }
    }

    private func reload() {
        Task { await loadSouler() }
    }

    @MainActor
    private func loadSouler() async {
        if isLoading { return }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let loadedSouler = try await Souler.get(soulerId)
            souler = loadedSouler
            isBookmarked = (try? await SoulerBookmark.contains(soulerId: loadedSouler.id)) ?? false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func toggleBookmark() {
        guard let souler, !isBookmarking else { return }

        let nextValue = !isBookmarked
        isBookmarked = nextValue
        isBookmarking = true
        bookmarkErrorMessage = nil

        Task {
            do {
                try await SoulerBookmark.setBookmarked(nextValue, soulerId: souler.id)
                NotificationCenter.default.post(name: .bookselfDidChange, object: nil)
            } catch {
                isBookmarked.toggle()
                bookmarkErrorMessage = error.localizedDescription
            }
            isBookmarking = false
        }
    }
}

private struct SoulerActionMenu: View {
    let onFeedback: () -> Void

    var body: some View {
        Menu {
            Button(action: onFeedback) {
                Label("souler.feedback.title", systemImage: "text.bubble")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18))
                .foregroundStyle(UITheme.primaryText)
        }
        .accessibilityLabel(Text("souler.action.more"))
    }
}



private struct SoulerContent: View {
    let souler: Souler?
    let isLoading: Bool
    let errorMessage: String?
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            if let souler {
                SoulerProfileSection(souler: souler)
            } else if let errorMessage {
                SoulerErrorView(message: errorMessage, onRetry: onRetry)
                    .frame(maxWidth: .infinity, minHeight: 300)
            } else if isLoading {
                SoulerProfileSkeleton()
            }
        }
        .frame(maxWidth: 560)
        .frame(maxWidth: .infinity)
    }
}

private struct SoulerProfileSection: View {
    let souler: Souler

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                SoulerPortraitView(name: souler.name, imageURL: souler.imageURL)
                    .frame(width: 116)

                VStack(alignment: .leading, spacing: 14) {
                    Text(souler.name)
                        .font(.title2.weight(.semibold))
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.primaryText)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    if !souler.keywords.isEmpty {
                        SoulerKeywordCloud(keywords: souler.keywords)
                    }
                }
                .padding(.top, 2)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(souler.introduction.isEmpty ? String(localized: "souler.introduction.empty.body") : souler.introduction)
                .font(.body)
                .fontDesign(.serif)
                .lineSpacing(7)
                .foregroundStyle(UITheme.primaryText.opacity(0.82))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct SoulerPortraitView: View {
    let name: String
    let imageURL: URL?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))

            if imageURL != nil {
                CachedRemoteImage(url: imageURL, contentMode: .fill) {
                    SoulerPortraitFallback(name: name)
                }
            } else {
                SoulerPortraitFallback(name: name)
            }
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .clipShape(.rect(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

private struct SoulerPortraitFallback: View {
    let name: String

    private var initial: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "?"
    }

    var body: some View {
        Text(initial)
            .font(.largeTitle.weight(.semibold))
            .fontDesign(.serif)
            .foregroundStyle(UITheme.tertiaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SoulerKeywordCloud: View {
    let keywords: [String]

    var body: some View {
        FlowLayout(spacing: 8, lineSpacing: 8) {
            ForEach(keywords, id: \.self) { keyword in
                Text(keyword)
                    .font(.caption)
                    .foregroundStyle(UITheme.secondaryText)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.white.opacity(0.05), in: .capsule)
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.12), lineWidth: 0.7)
                    }
            }
        }
    }
}

private struct SoulerErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Text("souler.load.failed")
                .font(.title3.weight(.semibold))
                .foregroundStyle(UITheme.primaryText)

            Text(message)
                .font(.footnote.weight(.medium))
                .foregroundStyle(UITheme.secondaryText)
                .multilineTextAlignment(.center)

            Button("common.retry", action: onRetry)
                .buttonStyle(.bordered)
                .tint(UITheme.primaryText)
        }
    }
}

private struct SoulerProfileSkeleton: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack(alignment: .top, spacing: 16) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .frame(width: 116)

                VStack(alignment: .leading, spacing: 14) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.12))
                        .frame(width: 132, height: 26)

                    HStack {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.08))
                            .frame(width: 54, height: 22)
                        RoundedRectangle(cornerRadius: 10)
                            .fill(.white.opacity(0.08))
                            .frame(width: 72, height: 22)
                    }
                }
                .padding(.top, 2)
            }

            VStack(alignment: .leading, spacing: 12) {
                ForEach(0 ..< 5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.white.opacity(0.08))
                        .frame(maxWidth: index == 4 ? 220 : .infinity, minHeight: 16, maxHeight: 16)
                }
            }
        }
        .redacted(reason: .placeholder)
    }
}

private struct FlowLayout: Layout {
    var spacing: CGFloat
    var lineSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = makeRows(proposal: proposal, subviews: subviews)
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.last.map { $0.y + $0.height } ?? 0
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        for row in makeRows(proposal: proposal, subviews: subviews) {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private func makeRows(proposal: ProposedViewSize, subviews: Subviews) -> [FlowRow] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [FlowRow] = []
        var currentItems: [FlowItem] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0
        var currentY: CGFloat = 0

        func commitRow() {
            guard !currentItems.isEmpty else { return }
            rows.append(FlowRow(y: currentY, width: currentWidth, height: currentHeight, items: currentItems))
            currentY += currentHeight + lineSpacing
            currentItems = []
            currentWidth = 0
            currentHeight = 0
        }

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = currentItems.isEmpty ? size.width : currentWidth + spacing + size.width
            if nextWidth > maxWidth, !currentItems.isEmpty {
                commitRow()
            }

            let x = currentItems.isEmpty ? 0 : currentWidth + spacing
            currentItems.append(FlowItem(index: index, x: x, size: size))
            currentWidth = currentItems.isEmpty ? size.width : x + size.width
            currentHeight = max(currentHeight, size.height)
        }

        commitRow()
        return rows
    }

    private struct FlowRow {
        var y: CGFloat
        var width: CGFloat
        var height: CGFloat
        var items: [FlowItem]
    }

    private struct FlowItem {
        var index: Int
        var x: CGFloat
        var size: CGSize
    }
}

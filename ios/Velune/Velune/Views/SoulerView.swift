import MarkdownUI
import SwiftUI

struct SoulerView: View {
    let soulerId: UUID
    @State private var souler: Souler?
    @State private var chapters: [SoulerChapter] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showNavigationTitle = false
    @State private var nameBlockHeight: CGFloat = 0
    private let navTitleThreshold: CGFloat = 12

    var body: some View {
        ZStack {
            BackgroundView()

            contentView
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(souler?.name ?? "")
                    .font(.headline.weight(.semibold))
                    .fontDesign(.serif)
                    .lineLimit(1)
                    .opacity(showNavigationTitle ? 1 : 0)
                    .animation(.easeInOut(duration: 0.16), value: showNavigationTitle)
            }
        }
        .task(id: soulerId) {
            await loadSouler()
        }
    }

    private var contentView: some View {
        Group {
            if let souler = souler {
                soulerDetailView(souler)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 12) {
                    Text("souler.load.failed")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(UITheme.primaryText)

                    Text(errorMessage)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(UITheme.secondaryText)
                        .multilineTextAlignment(.center)

                    Button("common.retry") {
                        Task {
                            await loadSouler()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ProgressView("common.loading")
                    .tint(UITheme.accent)
            }
        }
        .animation(.easeInOut, value: souler != nil)
    }

    @ViewBuilder
    private func soulerDetailView(_ souler: Souler) -> some View {
        if souler.bio.isEmpty, chapters.isEmpty {
            SereneContentUnavailableView(
                title: "souler.bio.empty.title",
                symbol: "sparkles",
                actionTitle: "common.refresh",
                actionIcon: "arrow.clockwise"
            ) {
                Task {
                    await loadSouler()
                }
            }
        } else {
            ScrollView {
                VStack(spacing: 20) {
                    Text(souler.name)
                        .font(.title2.weight(.semibold))
                        .fontDesign(.serif)
                        .multilineTextAlignment(.center)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 20)
                        .background {
                            GeometryReader { geometry in
                                Color.clear
                                    .onAppear {
                                        nameBlockHeight = geometry.size.height
                                    }
                            }
                        }

                    if !souler.bio.isEmpty {
                        Markdown(souler.bio)
                            .veluneMarkdownBodyStyle()
                            .frame(maxWidth: 560, alignment: .leading)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 24, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .padding(.horizontal)
                    }

                    SoulerChapterSection(
                        soulerName: souler.name,
                        soulerId: souler.id,
                        chapters: chapters
                    )
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .onScrollGeometryChange(
                for: CGFloat.self,
                of: { geometry in
                    geometry.contentOffset.y + geometry.contentInsets.top
                },
                action: { _, visibleOffsetY in
                    let trigger = max(24, nameBlockHeight + navTitleThreshold)
                    showNavigationTitle = visibleOffsetY > trigger
                }
            )
            .onAppear {
                showNavigationTitle = false
            }
        }
    }

    private func loadSouler() async {
        if isLoading { return }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            async let soulerResult = Souler.get(soulerId)
            async let chapterResult = SoulerChapter.fetchList(for: soulerId)
            let result = try await soulerResult
            let loadedChapters = (try? await chapterResult) ?? []
            await MainActor.run {
                souler = result
                chapters = loadedChapters
                showNavigationTitle = false
                nameBlockHeight = 0
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

private struct SoulerChapterSection: View {
    let soulerName: String
    let soulerId: UUID
    let chapters: [SoulerChapter]

    var body: some View {
        if !chapters.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("resonance.chat.chapters.title")
                    .font(.headline.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText)

                VStack(spacing: 0) {
                    ForEach(chapters) { chapter in
                        NavigationLink {
                            ChatView(
                                sessionId: nil,
                                soulerId: soulerId,
                                soulerName: soulerName,
                                focusComposerOnAppear: false
                            )
                        } label: {
                            ChapterRow(chapter: chapter)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(.white.opacity(0.05), in: .rect(cornerRadius: 16, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 0.7)
                }
            }
            .frame(maxWidth: 560, alignment: .leading)
        }
    }
}

private struct ChapterRow: View {
    let chapter: SoulerChapter

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(String(format: "%02d", chapter.seq))
                .font(.caption.weight(.semibold))
                .fontDesign(.rounded)
                .foregroundStyle(UITheme.tertiaryText)
                .frame(width: 28, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(chapter.title)
                    .font(.body.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText)
                    .lineLimit(2)

                if !chapter.subtitle.isEmpty {
                    Text(chapter.subtitle)
                        .font(.footnote)
                        .foregroundStyle(UITheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(UITheme.tertiaryText)
                .padding(.top, 3)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 0.5)
                .padding(.leading, 54)
        }
    }
}

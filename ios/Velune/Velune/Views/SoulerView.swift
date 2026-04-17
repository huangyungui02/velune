import MarkdownUI
import SwiftUI

struct SoulerView: View {
    let soulerId: UUID
    @State private var souler: Souler?
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
        if souler.bio.isEmpty {
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
                VStack(spacing: 16) {
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

                    Markdown(souler.bio)
                        .veluneMarkdownBodyStyle()
                        .frame(maxWidth: 560, alignment: .leading)
                        .padding()
                        .background(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding()
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
            let result = try await Souler.get(soulerId)
            await MainActor.run {
                souler = result
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

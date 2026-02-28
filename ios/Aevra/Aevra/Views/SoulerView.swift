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
                    .font(UITheme.literary(size: 17, weight: .semibold))
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
                    Text(L10n.string("souler.load.failed"))
                        .font(.system(size: 21, weight: .medium, design: .rounded))
                        .fontWeight(.semibold)
                        .foregroundStyle(UITheme.primaryText)

                    Text(errorMessage)
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(UITheme.secondaryText)
                        .multilineTextAlignment(.center)

                    Button(L10n.string("common.retry")) {
                        Task {
                            await loadSouler()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ProgressView(L10n.string("common.loading"))
                    .tint(UITheme.accent)
            }
        }
        .animation(.easeInOut, value: souler != nil)
    }

    private func soulerDetailView(_ souler: Souler) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(souler.name)
                    .font(UITheme.literary(size: 24, weight: .semibold))
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

                CardView {
                    Markdown(souler.bio)
                        .markdownTextStyle {
                            FontFamily(.custom(UITheme.literaryFontName))
                            FontSize(18)
                            ForegroundColor(UITheme.primaryText)
                        }
                        .lineSpacing(8)
                }.padding()
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

#Preview {
    NavigationStack {
        SoulerView(soulerId: Souler.sampleData[0].id)
    }
}

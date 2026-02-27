import SwiftUI

struct MatchingView: View {
    @Environment(\.dismiss) private var dismiss
    
    @State private var manager = MatchingManager.shared
    @State private var showError = false
    @State private var currentPage: CardID? = .glimmer
    
    private var echoes: [Echo] {
        (manager.currentGlimmer?.echoes ?? [])
            .sorted { $0.createdAt < $1.createdAt }
    }
    
    private var hasEchoes: Bool {
        !echoes.isEmpty
    }
    
    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 16) {
                cardPagerView
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.vertical)

                indicatorView
            }
        }
        .onChange(of: manager.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert(String(localized: "matching.error.title"), isPresented: $showError) {
            Button(String(localized: "common.ok"), role: .cancel) {
                manager.reset()
                dismiss()
            }
        } message: {
            Text(manager.errorMessage ?? String(localized: "matching.error.unknown"))
        }
    }
    
    private var cardPagerView: some View {
        GeometryReader { proxy in
            let maxCardHeight = proxy.size.height
            let cardHeightLimit = maxCardHeight > 0 ? maxCardHeight : nil

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    // Soul Fragment card
                    glimmerCard(maxCardHeight: maxCardHeight)
                        .containerRelativeFrame(.horizontal)
                        .id(CardID.glimmer)

                    // Echo cards
                    ForEach(echoes) { echo in
                        EchoCardView(
                            echo: echo,
                            glimmerContent: manager.text,
                            maxCardHeight: cardHeightLimit
                        )
                        .containerRelativeFrame(.horizontal)
                        .id(CardID.echo(echo.id))
                    }
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.paging)
            .scrollPosition(id: $currentPage)
            .scrollIndicators(.hidden)
            .onChange(of: hasEchoes) { _, newValue in
                // Switch to first echo when echoes appear
                if newValue, case .glimmer = currentPage {
                    if let firstEcho = echoes.first {
                        withAnimation {
                            currentPage = .echo(firstEcho.id)
                        }
                    }
                }
            }
        }
    }
    
    private func glimmerCard(maxCardHeight: CGFloat) -> some View {
        let cardHeightLimit = maxCardHeight > 0 ? maxCardHeight : nil
        return GlimmerCardView(content: manager.text, maxCardHeight: cardHeightLimit)
    }
    
    private var indicatorView: some View {
        HStack(spacing: 8) {
            EchoPagerIndicatorView(echoes: echoes, currentPage: $currentPage)
            
            if manager.isMatching {
                HStack(spacing: 12) {
                    MatchingWaveIcon()
                    
                    if !hasEchoes {
                        Text(String(localized: "matching.status.listening"))
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(UITheme.secondaryText)
                            .tracking(2)
                    }
                }
                .padding()
                .glassEffect()
            }
        }
    }
}

#Preview {
    ZStack {
        BackgroundView()
        EchoCardView(echo: Echo.sampleData[0], glimmerContent: Glimmer.sampleData[0].content)
    }
}

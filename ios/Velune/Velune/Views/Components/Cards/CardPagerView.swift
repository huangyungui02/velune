import SwiftUI

struct CardPagerView<StirringCard: View>: View {
    let echoes: [Echo]
    @Binding var currentPage: CardID?
    let autoSwitchToFirstEcho: Bool
    let stirringCard: () -> StirringCard

    private var hasEchoes: Bool {
        !echoes.isEmpty
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                stirringCard()
                    .containerRelativeFrame(.horizontal)
                    .id(CardID.stirring)

                ForEach(echoes) { echo in
                    EchoCardView(echo: echo)
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
            guard autoSwitchToFirstEcho, newValue else { return }
            guard case .stirring = currentPage else { return }
            guard let firstEcho = echoes.first else { return }

            UIImpactFeedbackGenerator(style: .light).impactOccurred()

            withAnimation(.easeInOut(duration: 0.8)) {
                currentPage = .echo(firstEcho.id)
            }
        }
    }
}

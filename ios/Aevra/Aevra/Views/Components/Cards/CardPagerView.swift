import SwiftUI

struct CardPagerView<GlimmerCard: View, EchoCard: View>: View {
    let echoes: [Echo]
    @Binding var currentPage: CardID?
    let autoSwitchToFirstEcho: Bool
    let glimmerCard: () -> GlimmerCard
    let echoCard: (Echo) -> EchoCard

    private var hasEchoes: Bool {
        !echoes.isEmpty
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                glimmerCard()
                    .containerRelativeFrame(.horizontal)
                    .id(CardID.glimmer)

                ForEach(echoes) { echo in
                    echoCard(echo)
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
            guard case .glimmer = currentPage else { return }
            guard let firstEcho = echoes.first else { return }

            withAnimation {
                currentPage = .echo(firstEcho.id)
            }
        }
    }
}

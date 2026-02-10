import SwiftUI

struct EchoPagerIndicatorView: View {
    let echoes: [Echo]
    @Binding var currentPage: CardID?

    var body: some View {
        if !echoes.isEmpty {
            HStack(spacing: 8) {
                Button {
                    withAnimation {
                        currentPage = .soulFragment
                    }
                } label: {
                    Image(systemName: "sparkle")
                        .font(.caption2)
                        .foregroundStyle(currentPage == .soulFragment ? .white : .white.opacity(0.3))
                        .frame(width: 10, height: 10)
                        .scaleEffect(currentPage == .soulFragment ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                }
                .buttonStyle(.plain)

                ForEach(echoes) { echo in
                    Circle()
                        .fill(currentPage == .echo(echo.id) ? .white : .white.opacity(0.3))
                        .frame(width: 8, height: 8)
                        .scaleEffect(currentPage == .echo(echo.id) ? 1.2 : 1.0)
                        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                }
            }
            .padding()
            .glassEffect()
        }
    }
}

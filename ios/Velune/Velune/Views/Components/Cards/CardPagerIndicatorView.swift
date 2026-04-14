import SwiftUI

struct CardPagerIndicatorView: View {
    let echoes: [Echo]
    @Binding var currentPage: CardID?
    let isMatching: Bool
    @State private var isScrubbing = false
    @State private var suppressTapUntil = Date.distantPast

    private let dotSize: CGFloat = 8
    private let dotSpacing: CGFloat = 8

    private var pages: [CardID] {
        [.stirring] + echoes.map { .echo($0.id) }
    }

    var body: some View {
        if !echoes.isEmpty {
            HStack(spacing: dotSpacing) {
                ForEach(pages.indices, id: \.self) { index in
                    Circle()
                        .fill(currentPage == pages[index] ? UITheme.accent : UITheme.tertiaryText)
                        .frame(width: dotSize, height: dotSize)
                        .scaleEffect(currentPage == pages[index] ? 1.2 : 1.0)
                        .animation(.spring(response: 0.28, dampingFraction: 0.75), value: currentPage)
                        .contentShape(Rectangle())
                        .onTapGesture {
                            guard !isScrubbing else { return }
                            guard Date() >= suppressTapUntil else { return }
                            selectPage(at: index)
                        }
                }
                if isMatching {
                    MatchingWaveIcon(ringSize: 6, containerSize: 12)
                }
            }
            .contentShape(Rectangle())
            .highPriorityGesture(scrubGesture)
            .padding()
        }
    }

    init(
        echoes: [Echo],
        currentPage: Binding<CardID?>,
        isMatching: Bool = false
    ) {
        self.echoes = echoes
        self._currentPage = currentPage
        self.isMatching = isMatching
    }

    private var scrubGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.15, maximumDistance: 20)
            .sequenced(before: DragGesture(minimumDistance: 0, coordinateSpace: .local))
            .onChanged { value in
                switch value {
                case .first(true):
                    isScrubbing = false
                case .second(true, let drag?):
                    isScrubbing = true
                    updateSelection(for: drag.location.x)
                default:
                    break
                }
            }
            .onEnded { _ in
                if isScrubbing {
                    suppressTapUntil = Date().addingTimeInterval(0.22)
                }
                isScrubbing = false
            }
    }

    private func selectPage(at index: Int) {
        guard pages.indices.contains(index) else { return }
        withAnimation(.spring(response: 0.28, dampingFraction: 0.75)) {
            currentPage = pages[index]
        }
    }

    private func updateSelection(for locationX: CGFloat) {
        guard pages.count > 1 else { return }

        let step = dotSize + dotSpacing
        let normalizedIndex = Int(round((locationX - (dotSize / 2)) / step))
        let clampedIndex = max(0, min(pages.count - 1, normalizedIndex))
        let targetPage = pages[clampedIndex]

        guard currentPage != targetPage else { return }
        withAnimation(.interactiveSpring(response: 0.22, dampingFraction: 0.82)) {
            currentPage = targetPage
        }
    }
}

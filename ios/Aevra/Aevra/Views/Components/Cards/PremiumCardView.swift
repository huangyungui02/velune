import SwiftUI

struct PremiumCardView<Content: View>: View {
    private let content: Content

    @State private var contentHeight: CGFloat = 0

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let cap = maxContentHeight(for: proxy.size.height)
            let isScrollable = contentHeight > cap
            let cardHeight = isScrollable ? cap : (contentHeight == 0 ? nil : contentHeight)

            VStack(spacing: 0) {
                if !isScrollable {
                    Spacer(minLength: 0)
                }

                scrollableContent(maxCardHeight: cap, isScrollable: isScrollable)
                    .frame(height: cardHeight, alignment: .top)
                    .padding(.vertical)
                    .frame(maxWidth: .infinity)
                    .background(Color.clear, in: .rect(cornerRadius: 28))
                    .glassEffect(in: .rect(cornerRadius: 28))
                    .padding(.horizontal)

                if !isScrollable {
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func scrollableContent(maxCardHeight: CGFloat, isScrollable: Bool) -> some View {
        return ScrollView {
            VStack {
                VStack(spacing: 20) {
                    content
                        .padding(.horizontal, 24)
                }
                .padding(.top, 26)
                .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity)
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: ContentHeightKey.self, value: proxy.size.height)
                }
            )
        }
        .scrollDisabled(!isScrollable)
        .frame(maxHeight: maxCardHeight, alignment: .top)
        .onPreferenceChange(ContentHeightKey.self) { newValue in
            if contentHeight != newValue {
                contentHeight = newValue
            }
        }
    }

    private func maxContentHeight(for maxCardHeight: CGFloat) -> CGFloat {
        guard maxCardHeight > 0 else { return .infinity }
        return max(0, maxCardHeight - 40)
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

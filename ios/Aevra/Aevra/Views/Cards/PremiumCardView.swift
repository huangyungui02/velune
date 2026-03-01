import SwiftUI

struct PremiumCardView<Content: View>: View {
    private let iconName: String
    private let content: Content
    private let maxCardHeight: CGFloat?
    private let followBottomOnContentGrowth: Bool

    @State private var contentHeight: CGFloat = 0
    private let bottomAnchorId = "premium-card-bottom-anchor"

    init(
        iconName: String,
        maxCardHeight: CGFloat? = nil,
        followBottomOnContentGrowth: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.iconName = iconName
        self.maxCardHeight = maxCardHeight
        self.followBottomOnContentGrowth = followBottomOnContentGrowth
        self.content = content()
    }

    var body: some View {
        scrollableContent
            .padding(.vertical)
            .frame(maxWidth: .infinity)
            .background(Color.clear, in: .rect(cornerRadius: 28))
            .overlay(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .stroke(
                        LinearGradient(
                            colors: [.white.opacity(0.30), .white.opacity(0.10)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
            .shadow(color: .black.opacity(0.18), radius: 20, x: 0, y: 14)
            .glassEffect(in: .rect(cornerRadius: 28))
            .padding(.horizontal)
    }

    private var headerView: some View {
        Image(systemName: iconName)
            .font(.headline.weight(.semibold))
            .foregroundStyle(UITheme.primaryText)
            .frame(width: 40, height: 40)
            .background(.white.opacity(0.14), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
    }

    private var scrollableContent: some View {
        let cap = maxContentHeight

        return ScrollViewReader { proxy in
            ScrollView {
                VStack {
                    VStack(spacing: 20) {
                        headerView

                        content
                            .padding(.horizontal, 20)
                    }

                    Color.clear
                        .frame(height: 1)
                        .id(bottomAnchorId)
                }
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                )
            }
            .scrollDisabled(contentHeight <= cap)
            .frame(height: contentHeight == 0 ? nil : min(contentHeight, cap), alignment: .top)
            .onPreferenceChange(ContentHeightKey.self) { newValue in
                let shouldFollow = followBottomOnContentGrowth && newValue > contentHeight
                if contentHeight != newValue {
                    contentHeight = newValue
                }
                guard shouldFollow else { return }
                DispatchQueue.main.async {
                    withAnimation(.easeOut(duration: 0.2)) {
                        proxy.scrollTo(bottomAnchorId, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var maxContentHeight: CGFloat {
        guard let maxCardHeight else { return .infinity }
        return max(0, maxCardHeight - 40)
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

import SwiftUI

struct PremiumCardView<Content: View>: View {
    private let iconName: String
    private let content: Content
    private let maxCardHeight: CGFloat?
    
    @State private var contentHeight: CGFloat = 0
    
    init(
        iconName: String,
        maxCardHeight: CGFloat? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.iconName = iconName
        self.maxCardHeight = maxCardHeight
        self.content = content()
    }
    
    var body: some View {
        scrollableContent
        .padding(.vertical, 20)
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
        .padding(.horizontal, 16)
    }

    private var headerView: some View {
        Image(systemName: iconName)
            .font(.system(size: 17, weight: .semibold, design: .rounded))
            .foregroundStyle(UITheme.primaryText)
            .frame(width: 40, height: 40)
            .background(.white.opacity(0.14), in: Circle())
            .overlay(Circle().stroke(.white.opacity(0.18), lineWidth: 1))
    }
    
    private var scrollableContent: some View {
        let cap = maxContentHeight

        return ScrollView {
            VStack(spacing: 20) {
                headerView
                content
                    .padding(.horizontal, 20)
            }
            .padding(.vertical, 10)
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
            if contentHeight != newValue {
                contentHeight = newValue
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

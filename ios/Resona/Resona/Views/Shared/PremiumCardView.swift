import SwiftUI

/// A reusable card component with icon header and scrollable content
/// Used for displaying soul fragments and echo responses
struct PremiumCardView<Content: View>: View {
    private let iconName: String
    private let content: Content
    private let maxContentHeight: CGFloat?
    
    @State private var contentHeight: CGFloat = 0
    
    init(
        iconName: String,
        maxContentHeight: CGFloat? = 450,
        @ViewBuilder content: () -> Content
    ) {
        self.iconName = iconName
        self.maxContentHeight = maxContentHeight
        self.content = content()
    }
    
    var body: some View {
        VStack(spacing: 16) {
            headerView
            scrollableContent
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .glassEffect(in: .rect(cornerRadius: 32))
        .padding(.horizontal, 24)
    }
    
    private var headerView: some View {
        Image(systemName: iconName)
            .font(.title2)
            .foregroundStyle(.white.opacity(0.9))
    }
    
    private var scrollableContent: some View {
        let cap = maxContentHeight ?? .infinity
        return ScrollView {
            content
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
                .background(
                    GeometryReader { proxy in
                        Color.clear
                            .preference(key: ContentHeightKey.self, value: proxy.size.height)
                    }
                )
        }
        .scrollDisabled(contentHeight <= cap)
        .frame(height: contentHeight == 0 ? nil : min(contentHeight, cap))
        .onPreferenceChange(ContentHeightKey.self) { newValue in
            if contentHeight != newValue {
                contentHeight = newValue
            }
        }
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

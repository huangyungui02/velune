import SwiftUI

struct CardView<Content: View>: View {
    private let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 16))
    }
}

#Preview {
    Group {
        CardView { Text("Hello, World!") }
    }
}

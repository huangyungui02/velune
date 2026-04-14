import SwiftUI

struct MatchingWaveIcon: View {
    var ringSize: CGFloat = 8
    var containerSize: CGFloat = 12
    var color: Color = UITheme.accent

    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .stroke(color, lineWidth: 1)
                    .frame(width: ringSize, height: ringSize)
                    .scaleEffect(animate ? 2.1 : 0.2)
                    .opacity(animate ? 0.0 : 0.75)
                    .animation(
                        .easeOut(duration: 2.6)
                            .repeatForever(autoreverses: false)
                            .delay(Double(index) * 0.6),
                        value: animate
                    )
            }
        }
        .frame(width: containerSize, height: containerSize)
        .onAppear {
            animate = true
        }
    }
}

import SwiftUI

struct MatchingWaveIcon: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .stroke(UITheme.accent, lineWidth: 1)
                    .frame(width: 8, height: 8)
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
        .frame(width: 12, height: 12)
        .onAppear {
            animate = true
        }
    }
}

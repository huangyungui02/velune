import SwiftUI

struct StarlightWaitingPlaceholderView: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: "sparkle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(UITheme.glimmerGlow)
                    .scaleEffect(animate ? 1.25 : 0.7)
                    .offset(y: animate ? -3.5 : 3.5)
                    .opacity(animate ? 1.0 : 0.25)
                    .shadow(color: UITheme.glimmerGlow.opacity(0.8), radius: animate ? 5 : 1)
                    .animation(
                        .easeInOut(duration: 1.4)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.32),
                        value: animate
                    )
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear {
            animate = true
        }
    }
}

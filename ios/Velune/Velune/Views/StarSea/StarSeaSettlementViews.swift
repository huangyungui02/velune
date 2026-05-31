import SwiftUI

struct AmbientMistView: View {
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Left subtle smoke
            Ellipse()
                .fill(Color(white: 0.15).opacity(0.35))
                .frame(width: 320, height: 450)
                .blur(radius: 90)
                .offset(x: pulse ? -60 : -100, y: pulse ? 100 : 60)

            // Right subtle smoke
            Ellipse()
                .fill(Color(white: 0.12).opacity(0.3))
                .frame(width: 360, height: 480)
                .blur(radius: 100)
                .offset(x: pulse ? 120 : 70, y: pulse ? -80 : -120)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 8.0).repeatForever(autoreverses: true)) {
                pulse.toggle()
            }
        }
    }
}

struct ImmersiveSettlementView: View {
    let text: String
    let isGenerating: Bool
    let isReady: Bool
    let onExit: () -> Void

    @State private var cardOpacity: Double = 0
    @State private var cardScale: CGFloat = 0.96

    var body: some View {
        ZStack {
            StarryBackgroundView().ignoresSafeArea()

            VStack {
                Spacer()

                // Original GlimmerCardView for seamless UI consistency
                GlimmerCardView(
                    content: text,
                    isGenerating: isGenerating
                )
                .padding(.horizontal, 20)
                .scaleEffect(cardScale)
                .opacity(cardOpacity)

                Spacer()

                // "静候安澜" Button
                if isReady {
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.6)) {
                            cardOpacity = 0
                            cardScale = 0.92
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            onExit()
                        }
                    }) {
                        Text("starsea.settlement.settleButton")
                            .font(.system(size: 15, weight: .light, design: .serif))
                            .foregroundStyle(.white.opacity(0.7))
                            .tracking(2.0)
                            .padding(.horizontal, 28)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
                                    .background(Color.white.opacity(0.01))
                            )
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 24)
                    .transition(.opacity)
                }
            }
        }
        .onAppear {
            withAnimation(.spring(response: 0.75, dampingFraction: 0.82)) {
                cardOpacity = 1
                cardScale = 1.0
            }
        }
    }
}

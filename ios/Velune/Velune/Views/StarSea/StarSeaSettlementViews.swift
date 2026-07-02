import SwiftUI

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

            VStack(spacing: 0) {
                GeometryReader { geometry in
                    ScrollView {
                        VStack(spacing: 0) {
                            GlimmerCardView(
                                content: text,
                                isGenerating: isGenerating
                            )
                            .scaleEffect(cardScale)
                            .opacity(cardOpacity)
                        }
                        .frame(minHeight: geometry.size.height)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 28)
                    }
                    .scrollIndicators(.hidden)
                }

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

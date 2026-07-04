import SwiftUI

struct DivinationView: View {
    @Binding var divinationData: DivinationData
    @Binding var isFinished: Bool
    @Binding var visibleLinesCount: Int
    @Binding var showTexts: Bool

    @State private var ripples: [Ripple] = []

    private struct Ripple: Identifiable {
        let id = UUID()
        let location: CGPoint
    }

    var body: some View {
        ZStack {
            if !isFinished {
                Color.clear
                    .contentShape(Rectangle())
                    .gesture(
                        SpatialTapGesture()
                            .onEnded { value in
                                if castedLineCount < 6 {
                                    handleTap(at: value.location)
                                }
                            }
                    )
            }

            ForEach(ripples) { ripple in
                MagicalTapView(location: ripple.location)
            }

            VStack {
                Spacer()

                if !isFinished {
                    castingPrompt
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if divinationData.castedLines.count == 6 {
                    DivinationResultCard(
                        divination: divinationData,
                        visibleLinesCount: visibleLinesCount,
                        showsDate: true
                    )
                    .onAppear(perform: triggerStaggeredReveal)
                }

                Spacer()

                if !isFinished {
                    Text(NSLocalizedString("divination.inspiredBy", comment: ""))
                        .font(.caption2.weight(.medium))
                        .tracking(1.2)
                        .foregroundStyle(UITheme.tertiaryText.opacity(0.55))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                        .padding(.bottom, 18)
                        .transition(.opacity)
                }
            }
        }
    }

    private var castingPrompt: some View {
        VStack(spacing: 24) {
            Text(NSLocalizedString("divination.focus.prompt", comment: ""))
                .font(.system(size: 20, weight: .medium, design: .serif))
                .tracking(2.0)
                .multilineTextAlignment(.center)
                .foregroundStyle(UITheme.primaryText)
                .padding(.horizontal, 40)

            Text(NSLocalizedString("divination.tap.prompt", comment: ""))
                .font(.footnote)
                .foregroundStyle(UITheme.secondaryText.opacity(0.58))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
                .opacity(castedLineCount == 0 ? 1.0 : 0.0)
                .scaleEffect(castedLineCount == 0 ? 1.0 : 0.96)
                .animation(.easeOut(duration: 0.35), value: castedLineCount)

            HStack(spacing: 16) {
                ForEach(0..<6, id: \.self) { index in
                    Circle()
                        .stroke(UITheme.glimmerGlow.opacity(index < castedLineCount ? 0.9 : 0.3), lineWidth: 1.5)
                        .background(
                            Circle()
                                .fill(index < castedLineCount ? UITheme.glimmerGlow : Color.clear)
                        )
                        .frame(width: 14, height: 14)
                        .shadow(color: index < castedLineCount ? UITheme.glimmerGlow.opacity(0.8) : Color.clear, radius: index < castedLineCount ? 6 : 0)
                        .scaleEffect(index < castedLineCount ? 1.15 : 1.0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.6), value: index < castedLineCount)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var castedLineCount: Int {
        divinationData.castedLines.count
    }

    private func handleTap(at location: CGPoint) {
        let ripple = Ripple(location: location)
        ripples.append(ripple)

        let rand = Double.random(in: 0...1)
        let lineCode: Int
        if rand < 0.375 {
            lineCode = 0
        } else if rand < 0.75 {
            lineCode = 1
        } else if rand < 0.875 {
            lineCode = 2
        } else {
            lineCode = 3
        }

        withAnimation(.spring(response: 0.35, dampingFraction: 0.6)) {
            divinationData.castedLines.append(lineCode)
        }

        if divinationData.castedLines.count == 6 {
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.prepare()
            successGenerator.notificationOccurred(.success)
            divinationData.date = Date()
        } else {
            let generator = UIImpactFeedbackGenerator(style: .light)
            generator.prepare()
            generator.impactOccurred()
            // generator.impactOccurred(intensity: 0.55)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            ripples.removeAll { $0.id == ripple.id }
        }

        if divinationData.castedLines.count == 6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                withAnimation(.easeInOut(duration: 0.5)) {
                    isFinished = true
                }
            }
        }
    }

    private func triggerStaggeredReveal() {
        visibleLinesCount = 0
        showTexts = false
        for i in 0...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.16) {
                withAnimation(.easeOut(duration: 0.3)) {
                    visibleLinesCount = i
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) {
            withAnimation(.easeOut(duration: 0.4)) {
                showTexts = true
            }
        }
    }
}

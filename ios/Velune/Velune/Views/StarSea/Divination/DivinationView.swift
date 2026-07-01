import SwiftUI

struct DivinationView: View {
    let onLeave: () -> Void
    let onStartInterpretation: (String, DivinationData) -> Void

    @State private var ripples: [Ripple] = []
    @State private var isFinished = false
    @State private var divinationData = DivinationData(castedLines: [], date: Date())
    
    @State private var visibleLinesCount = 0
    @State private var showTexts = false

    @State private var questionText = ""

    struct Ripple: Identifiable {
        let id = UUID()
        let location: CGPoint
    }

    var body: some View {
        ZStack {
            StarryBackgroundView()
                .contentShape(Rectangle())

            // Full-screen tap gesture area to collect 6 taps
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

            // Visual effects for taps
            ForEach(ripples) { ripple in
                MagicalTapView(location: ripple.location)
            }

            // Foreground UI
            VStack {
                // Custom Navigation Bar
                HStack {
                    Button(action: onLeave) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(UITheme.primaryText)
                            .frame(width: 44, height: 44)
                            .glassEffect(.regular.interactive(), in: .circle)
                    }
                    .buttonStyle(.plain)
                    
                    Spacer()
                    
                    // Recast button in the top-right toolbar area
                    if isFinished || castedLineCount > 0 {
                        Button(action: recast) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(UITheme.primaryText)
                                .frame(width: 44, height: 44)
                                .glassEffect(.regular.interactive(), in: .circle)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)

                Spacer()

                if !isFinished {
                    // Casting Interface
                    VStack(spacing: 48) {
                        Text(NSLocalizedString("divination.focus.prompt", comment: ""))
                            .font(.system(size: 20, weight: .medium, design: .serif))
                            .tracking(2.0)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(UITheme.primaryText)
                            .padding(.horizontal, 40)

                        // Graphical Progress Dots
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
                        .padding(.vertical, 12)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.98)))
                } else if divinationData.castedLines.count == 6 {
                    // Result Interface - displaying only the aligned hexagram diagrams and names
                    DivinationResultCard(
                        divination: divinationData,
                        visibleLinesCount: visibleLinesCount,
                        showsDate: true
                    )
                    .onAppear {
                        triggerStaggeredReveal()
                    }
                }

                Spacer()

                if !isFinished {
                    VStack(spacing: 10) {
                        Text(NSLocalizedString("divination.tap.prompt", comment: ""))
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText.opacity(0.65))

                        Text(NSLocalizedString("divination.inspiredBy", comment: ""))
                            .font(.caption2.weight(.medium))
                            .tracking(1.2)
                            .foregroundStyle(UITheme.tertiaryText.opacity(0.55))
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 34)
                    .transition(.opacity)
                }

                // Anchor input panel at the bottom of the screen (similar to the AI chat composer)
                if isFinished && showTexts {
                    HStack(alignment: .bottom, spacing: 8) {
                        TextField(NSLocalizedString("divination.input.placeholder", comment: ""), text: $questionText, axis: .vertical)
                            .font(.subheadline)
                            .foregroundStyle(UITheme.primaryText)
                            .lineLimit(2...5)
                            .tint(UITheme.primaryText)
                            .padding(.leading, 16)
                            .padding(.vertical, 12)
                        
                        Button(action: startInterpretationFlow) {
                            Image(systemName: "arrow.up")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(trimmedQuestion.isEmpty ? Color.white.opacity(0.3) : Color(red: 0.03, green: 0.035, blue: 0.055))
                                .frame(width: 32, height: 32)
                                .background(trimmedQuestion.isEmpty ? Color.white.opacity(0.1) : Color.white, in: .circle)
                                .shadow(color: trimmedQuestion.isEmpty ? Color.clear : UITheme.glimmerGlow.opacity(0.2), radius: 4)
                        }
                        .disabled(trimmedQuestion.isEmpty)
                        .padding(.trailing, 8)
                        .padding(.bottom, 8)
                        .buttonStyle(.plain)
                    }
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 20))
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 0.8)
                    }
                    .frame(maxWidth: 340)
                    .padding(.bottom, 24)
                    .transition(.opacity)
                }
            }
            .navigationBarBackButtonHidden(true)
            .toolbar(.hidden, for: .tabBar)
        }
    }

    private var trimmedQuestion: String {
        questionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var castedLineCount: Int {
        divinationData.castedLines.count
    }

    private func handleTap(at location: CGPoint) {
        let ripple = Ripple(location: location)
        ripples.append(ripple)

        // Distribute YaoStates: 37.5% Stable Yang, 37.5% Stable Yin, 12.5% Moving Yang, 12.5% Moving Yin
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

        // Point-of-impact immediate feedback. Trigger .success on the 6th tap, and .medium on others.
        if divinationData.castedLines.count == 6 {
            let successGenerator = UINotificationFeedbackGenerator()
            successGenerator.prepare()
            successGenerator.notificationOccurred(.success)

            divinationData.date = Date()
        } else {
            let generator = UIImpactFeedbackGenerator(style: .medium)
            generator.prepare()
            generator.impactOccurred()
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

    private func startInterpretationFlow() {
        let question = trimmedQuestion
        guard !question.isEmpty, divinationData.castedLines.count == 6 else { return }
        
        // Pass data and question to parent layout to trigger sheet dismissal and chat navigation
        onStartInterpretation(question, divinationData)
    }

    private func recast() {
        withAnimation(.easeInOut(duration: 0.4)) {
            isFinished = false
            visibleLinesCount = 0
            showTexts = false
            divinationData = DivinationData(castedLines: [], date: Date())
            questionText = ""
        }
    }
}

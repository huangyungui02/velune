import SwiftUI

struct ChatDivinationCardView: View {
    let divination: DivinationData

    var body: some View {
        DivinationResultCard(
            divination: divination,
            visibleLinesCount: 6,
            showsDate: true
        )
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.vertical, 8)
    }
}

struct YaoLineView: View {
    let type: YaoType
    let index: Int
    let visibleLinesCount: Int
    let width: CGFloat

    var body: some View {
        let isVisible = index < visibleLinesCount

        HStack(spacing: 8) {
            if type == .yang {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(UITheme.glimmerGlow)
                    .frame(height: 5)
            } else {
                RoundedRectangle(cornerRadius: 2.5)
                    .fill(UITheme.glimmerGlow)
                    .frame(height: 5)

                RoundedRectangle(cornerRadius: 2.5)
                    .fill(UITheme.glimmerGlow)
                    .frame(height: 5)
            }
        }
        .frame(width: width)
        .opacity(isVisible ? 1.0 : 0.0)
        .scaleEffect(isVisible ? 1.0 : 0.92)
    }
}

// Particle/glow effect for tap gesture
struct MagicalTapView: View {
    let location: CGPoint
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            // Ripple wave
            Circle()
                .stroke(UITheme.glimmerGlow.opacity(0.8), lineWidth: 1.5)
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 2.2 : 0.1)
                .opacity(isAnimating ? 0 : 0.8)

            // Inner soft pulse glow
            Circle()
                .fill(UITheme.glimmerGlow.opacity(0.15))
                .frame(width: 80, height: 80)
                .scaleEffect(isAnimating ? 1.8 : 0.1)
                .opacity(isAnimating ? 0 : 0.8)

            // Particles
            ForEach(0..<8) { index in
                let angle = Double(index) * (Double.pi / 4)
                let distance: CGFloat = isAnimating ? 80.0 : 0.0
                Image(systemName: "sparkle")
                    .font(.system(size: CGFloat.random(in: 8...14)))
                    .foregroundStyle(UITheme.glimmerGlow)
                    .offset(x: cos(angle) * distance, y: sin(angle) * distance)
                    .scaleEffect(isAnimating ? 0.2 : 1.0)
                    .opacity(isAnimating ? 0 : 0.95)
            }
        }
        .position(location)
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                isAnimating = true
            }
        }
    }
}

struct DivinationResultCard: View {
    let divination: DivinationData
    let visibleLinesCount: Int
    var showsDate = true

    let width: CGFloat = 100

    private var castedLines: [YaoState] {
        divination.yaoStates
    }

    private var primary: Hexagram {
        divination.primaryHexagram
    }

    private var changed: Hexagram {
        divination.changedHexagram
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 24) {
                // Primary Hexagram (主卦)
                VStack(spacing: 16) {
                    Text(NSLocalizedString("divination.result.primary", comment: ""))
                        .font(.caption)
                        .foregroundStyle(UITheme.tertiaryText)
                        .tracking(1.0)
                    
                    HexagramTitleView(hexagram: primary)
                    
                    VStack(spacing: 12) {
                        ForEach((0..<6).reversed(), id: \.self) { index in
                            let state = castedLines[index]
                            YaoLineView(
                                type: state.primaryType,
                                index: index,
                                visibleLinesCount: visibleLinesCount,
                                width: width
                            )
                        }
                    }
                    .frame(width: width, height: 110)
                }
                
                // Arrow Connector
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .light))
                    .foregroundStyle(UITheme.tertiaryText)
                    .offset(y: 20)
                
                // Changed Hexagram (变卦)
                VStack(spacing: 16) {
                    Text(NSLocalizedString("divination.result.changed", comment: ""))
                        .font(.caption)
                        .foregroundStyle(UITheme.tertiaryText)
                        .tracking(1.0)
                    
                    HexagramTitleView(hexagram: changed)
                    
                    VStack(spacing: 12) {
                        ForEach((0..<6).reversed(), id: \.self) { index in
                            let state = castedLines[index]
                            YaoLineView(
                                type: state.changedType,
                                index: index,
                                visibleLinesCount: visibleLinesCount,
                                width: width
                            )
                        }
                    }
                    .frame(width: width, height: 110)
                }
            }
            
            if showsDate {
                VStack(spacing: 10) {
                    Divider()
                        .background(Color.white.opacity(0.12))
                    
                    Text("\(String(localized: "divination.result.castTime")) \(divination.localizedDateString)")
                        .font(.system(size: 11))
                        .foregroundStyle(UITheme.tertiaryText)
                }
                .padding(.top, 24)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 32)
        .frame(maxWidth: 340)
        .glassEffect(in: .rect(cornerRadius: 24))
    }
}

private struct HexagramTitleView: View {
    let hexagram: Hexagram

    var body: some View {
        VStack(spacing: 4) {
            Text(hexagram.name)
                .font(.system(size: 16, weight: .bold, design: .serif))
                .foregroundStyle(UITheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            if let subtitle = hexagram.subtitle {
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(UITheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .multilineTextAlignment(.center)
        .frame(width: width, height: 34, alignment: .top)
    }

    private var width: CGFloat {
        108
    }
}

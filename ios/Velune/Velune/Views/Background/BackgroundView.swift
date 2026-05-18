import SwiftUI

struct BackgroundView: View {
    var body: some View {
        ZStack {
            Color(white: 0.02) // 极致深邃的纯粹底色

            NebulaOverlayView(opacity: 0.30)
        }
        .ignoresSafeArea()
    }
}

struct StarryBackgroundView: View {
    var body: some View {
        ZStack {
            BackgroundView()
//            StarFieldView(starCount: 75)
//                .opacity(0.65)
        }
        .ignoresSafeArea()
    }
}

private struct NebulaOverlayView: View {
    let opacity: CGFloat

    var body: some View {
        ZStack {
            RadialGradient(
                colors: [Color(white: 0.18).opacity(0.6), .clear],
                center: .topTrailing,
                startRadius: 100,
                endRadius: 600
            )

            // 核心深处的微弱星云，增加空间的纵深感，极度克制
            RadialGradient(
                colors: [Color(white: 0.10).opacity(0.4), .clear],
                center: UnitPoint(x: 0.4, y: 0.6),
                startRadius: 200,
                endRadius: 800
            )

            RadialGradient(
                colors: [Color(white: 0.15).opacity(0.5), .clear],
                center: .bottomLeading,
                startRadius: 50,
                endRadius: 500
            )
        }
        .opacity(opacity)
        .blendMode(.screen)
    }
}

struct StarFieldView: View {
    let starCount: Int
    @State private var stars: [Star] = []

    struct Star: Identifiable {
        let id = UUID()
        var x: CGFloat
        var y: CGFloat
        let size: CGFloat
        let baseOpacity: CGFloat
        let twinkleSpeed: Double
        let twinklePhase: Double
        let pulseSpeed: Double
        let pulsePhase: Double
        let driftSpeed: Double
        let driftAmplitude: CGFloat
        let driftAngle: Double
    }

    init(starCount: Int) {
        self.starCount = starCount
        _stars = State(initialValue: Self.makeStars(count: starCount))
    }

    var body: some View {
        GeometryReader { _ in
            // Draw twinkling and moving stars
            TimelineView(.periodic(from: .now, by: 1.0 / 30.0)) { timeline in
                Canvas { context, size in
                    let time = timeline.date.timeIntervalSinceReferenceDate

                    // Draw stars
                    for star in stars {
                        let twinkle = sin(time * star.twinkleSpeed + star.twinklePhase) * 0.5 + 0.5
                        let pulse = pow(max(0, sin(time * star.pulseSpeed + star.pulsePhase)), 4)
                        let shimmer = 0.5 + twinkle * 0.65 + pulse * 0.7
                        let opacity = min(1.0, star.baseOpacity * shimmer)

                        let drift = sin(time * star.driftSpeed + star.pulsePhase) * star.driftAmplitude
                        let x = wrappedUnit(star.x + cos(star.driftAngle) * drift)
                        let y = wrappedUnit(star.y + sin(star.driftAngle) * drift)

                        let rect = CGRect(
                            x: x * size.width - star.size / 2,
                            y: y * size.height - star.size / 2,
                            width: star.size,
                            height: star.size
                        )
                        context.fill(
                            Circle().path(in: rect),
                            with: .color(.white.opacity(opacity))
                        )
                    }
                }
            }
        }
        .ignoresSafeArea()
        .onAppear {
            if stars.isEmpty {
                stars = Self.makeStars(count: starCount)
            }
        }
    }

    private static func makeStars(count: Int) -> [Star] {
        (0 ..< count).map { _ in
            Star(
                x: CGFloat.random(in: -0.1...1.1),
                y: CGFloat.random(in: -0.1...1.1),
                size: CGFloat.random(in: 0.6...3.2),
                baseOpacity: CGFloat.random(in: 0.34...0.95),
                twinkleSpeed: Double.random(in: 1.8...6.6),
                twinklePhase: Double.random(in: 0...(Double.pi * 2)),
                pulseSpeed: Double.random(in: 0.45...1.4),
                pulsePhase: Double.random(in: 0...(Double.pi * 2)),
                driftSpeed: Double.random(in: 0.3...0.9),
                driftAmplitude: CGFloat.random(in: 0.002...0.010),
                driftAngle: Double.random(in: 0...(Double.pi * 2))
            )
        }
    }

    private func wrappedUnit(_ value: CGFloat) -> CGFloat {
        let wrapped = value.truncatingRemainder(dividingBy: 1.0)
        return wrapped < 0 ? wrapped + 1.0 : wrapped
    }
}

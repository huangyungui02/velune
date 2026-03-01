import SwiftUI

struct BackgroundView: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(white: 0.02),
                    Color(white: 0.05),
                    Color(white: 0.10),
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            NebulaOverlayView(opacity: 0.30)
        }
        .ignoresSafeArea()
    }
}

struct StarryBackgroundView: View {
    var body: some View {
        ZStack {
            BackgroundView()
            StarFieldView(starCount: 100, showsBackground: false)
                .opacity(0.65)
        }
        .ignoresSafeArea()
    }
}

private struct NebulaOverlayView: View {
    let opacity: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                MeshGradient(
                    width: 4,
                    height: 4,
                    points: meshPoints(at: time),
                    colors: meshColorsPrimary(),
                    background: Color.black,
                    smoothsColors: true
                )

                MeshGradient(
                    width: 4,
                    height: 4,
                    points: meshPointsSecondary(at: time),
                    colors: meshColorsSecondary(),
                    background: .clear,
                    smoothsColors: true
                )
                .blendMode(.softLight)
                .opacity(0.42)
            }
            .opacity(opacity)
            .blur(radius: 12)
        }
        .drawingGroup()
    }

    private func meshPoints(at time: TimeInterval) -> [SIMD2<Float>] {
        let t = Float(time)

        return [
            SIMD2(0.00, 0.00),
            SIMD2(0.33 + sin(t * 0.021) * 0.02, 0.00 + cos(t * 0.019) * 0.012),
            SIMD2(0.66 + sin(t * 0.018 + 0.8) * 0.018, 0.00 + cos(t * 0.017 + 0.4) * 0.012),
            SIMD2(1.00, 0.00),

            SIMD2(0.00 + cos(t * 0.017 + 0.7) * 0.012, 0.33 + sin(t * 0.016 + 0.5) * 0.02),
            SIMD2(0.33 + sin(t * 0.014 + 1.1) * 0.02, 0.33 + cos(t * 0.013 + 1.7) * 0.02),
            SIMD2(0.66 + sin(t * 0.015 + 0.9) * 0.018, 0.33 + cos(t * 0.014 + 0.6) * 0.02),
            SIMD2(1.00 + sin(t * 0.018 + 0.9) * 0.012, 0.33 + cos(t * 0.015 + 0.4) * 0.02),

            SIMD2(0.00 + cos(t * 0.016 + 1.4) * 0.012, 0.66 + sin(t * 0.015 + 1.0) * 0.018),
            SIMD2(0.33 + sin(t * 0.013 + 2.1) * 0.02, 0.66 + cos(t * 0.012 + 2.0) * 0.018),
            SIMD2(0.66 + sin(t * 0.014 + 2.4) * 0.018, 0.66 + cos(t * 0.013 + 2.3) * 0.018),
            SIMD2(1.00 + sin(t * 0.015 + 1.9) * 0.012, 0.66 + cos(t * 0.014 + 1.8) * 0.018),

            SIMD2(0.00, 1.00),
            SIMD2(0.33 + cos(t * 0.020 + 1.3) * 0.02, 1.00 + sin(t * 0.018 + 0.8) * 0.012),
            SIMD2(0.66 + cos(t * 0.017 + 2.0) * 0.018, 1.00 + sin(t * 0.016 + 1.6) * 0.012),
            SIMD2(1.00, 1.00),
        ]
    }

    private func meshPointsSecondary(at time: TimeInterval) -> [SIMD2<Float>] {
        let t = Float(time)

        return [
            SIMD2(0.00 + cos(t * 0.012) * 0.02, 0.00 + sin(t * 0.014) * 0.02),
            SIMD2(0.33 + sin(t * 0.017 + 0.8) * 0.022, 0.00 + cos(t * 0.015 + 0.3) * 0.015),
            SIMD2(0.66 + cos(t * 0.013 + 1.2) * 0.02, 0.00 + sin(t * 0.012 + 1.0) * 0.015),
            SIMD2(1.00 + cos(t * 0.011 + 1.7) * 0.02, 0.00 + sin(t * 0.013 + 0.6) * 0.015),

            SIMD2(0.00 + sin(t * 0.014 + 0.4) * 0.015, 0.33 + cos(t * 0.013 + 0.7) * 0.022),
            SIMD2(0.33 + cos(t * 0.011 + 1.7) * 0.024, 0.33 + sin(t * 0.012 + 1.6) * 0.024),
            SIMD2(0.66 + sin(t * 0.013 + 1.5) * 0.022, 0.33 + cos(t * 0.014 + 1.1) * 0.024),
            SIMD2(1.00 + cos(t * 0.012 + 2.0) * 0.015, 0.33 + sin(t * 0.013 + 1.8) * 0.022),

            SIMD2(0.00 + sin(t * 0.013 + 2.1) * 0.015, 0.66 + cos(t * 0.012 + 2.0) * 0.022),
            SIMD2(0.33 + cos(t * 0.015 + 2.2) * 0.024, 0.66 + sin(t * 0.014 + 2.1) * 0.022),
            SIMD2(0.66 + cos(t * 0.013 + 2.5) * 0.022, 0.66 + sin(t * 0.012 + 2.4) * 0.022),
            SIMD2(1.00 + sin(t * 0.014 + 2.8) * 0.015, 0.66 + cos(t * 0.013 + 2.7) * 0.022),

            SIMD2(0.00 + cos(t * 0.012 + 2.0) * 0.02, 1.00 + sin(t * 0.013 + 1.8) * 0.015),
            SIMD2(0.33 + sin(t * 0.015 + 2.2) * 0.022, 1.00 + cos(t * 0.014 + 2.1) * 0.015),
            SIMD2(0.66 + cos(t * 0.012 + 2.5) * 0.02, 1.00 + sin(t * 0.013 + 2.4) * 0.015),
            SIMD2(1.00 + cos(t * 0.012 + 2.5) * 0.02, 1.00 + sin(t * 0.013 + 2.4) * 0.015),
        ]
    }

    private func meshColorsPrimary() -> [Color] {
        [
            Color(white: 0.036),
            Color(white: 0.064),
            Color(white: 0.044),
            Color(white: 0.038),
            Color(white: 0.072),
            Color(white: 0.052),
            Color(white: 0.040),
            Color(white: 0.076),
            Color(white: 0.056),
            Color(white: 0.042),
            Color(white: 0.068),
            Color(white: 0.050),
            Color(white: 0.038),
            Color(white: 0.060),
            Color(white: 0.046),
            Color(white: 0.034),
        ]
    }

    private func meshColorsSecondary() -> [Color] {
        [
            Color(white: 0.00).opacity(0.00),
            Color(white: 0.22).opacity(0.10),
            Color(white: 0.00).opacity(0.00),
            Color(white: 0.18).opacity(0.08),
            Color(white: 0.00).opacity(0.00),
            Color(white: 0.20).opacity(0.09),
            Color(white: 0.28).opacity(0.13),
            Color(white: 0.19).opacity(0.08),
            Color(white: 0.00).opacity(0.00),
            Color(white: 0.18).opacity(0.08),
            Color(white: 0.24).opacity(0.11),
            Color(white: 0.17).opacity(0.07),
            Color(white: 0.00).opacity(0.00),
            Color(white: 0.00).opacity(0.00),
            Color(white: 0.19).opacity(0.09),
            Color(white: 0.00).opacity(0.00),
            Color(white: 0.00).opacity(0.00),
        ]
    }
}

struct StarFieldView: View {
    let starCount: Int
    let showsBackground: Bool
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

    init(starCount: Int = 100, showsBackground: Bool = true) {
        self.starCount = starCount
        self.showsBackground = showsBackground
        _stars = State(initialValue: Self.makeStars(count: starCount))
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                if showsBackground {
                    LinearGradient(
                        colors: [
                            Color(white: 0.03),
                            Color(white: 0.08),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                }

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

#Preview {
    BackgroundView()
}

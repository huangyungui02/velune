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

            NebulaOverlayView(opacity: 0.2)
        }
        .ignoresSafeArea()
    }
}

struct StarryBackgroundView: View {
    var body: some View {
        ZStack {
            BackgroundView()
            StarFieldView(starCount: 110, showsBackground: false)
                .opacity(0.55)
        }
        .ignoresSafeArea()
    }
}

private struct NebulaOverlayView: View {
    let opacity: CGFloat

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let time = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { proxy in
                let size = proxy.size
                ZStack {
                    MeshGradient(
                        width: 3,
                        height: 3,
                        points: meshPoints(at: time),
                        colors: meshColors(),
                        background: Color.black,
                        smoothsColors: true
                    )

                    RadialGradient(
                        stops: [
                            .init(color: Color.clear, location: 0.52),
                            .init(color: Color.black.opacity(0.28), location: 1.0),
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: max(size.width, size.height) * 0.95
                    )
                }
            }
            .opacity(opacity)
            .blur(radius: 36)
        }
        .drawingGroup()
    }

    private func meshPoints(at time: TimeInterval) -> [SIMD2<Float>] {
        let t = Float(time)

        return [
            SIMD2(0.00, 0.00),
            SIMD2(0.50 + sin(t * 0.021) * 0.03, 0.00 + cos(t * 0.019) * 0.02),
            SIMD2(1.00, 0.00),

            SIMD2(0.00 + cos(t * 0.017 + 0.7) * 0.02, 0.50 + sin(t * 0.016 + 0.5) * 0.03),
            SIMD2(0.50 + sin(t * 0.014 + 1.1) * 0.04, 0.50 + cos(t * 0.013 + 1.7) * 0.04),
            SIMD2(1.00 + sin(t * 0.018 + 0.9) * 0.02, 0.50 + cos(t * 0.015 + 0.4) * 0.03),

            SIMD2(0.00, 1.00),
            SIMD2(0.50 + cos(t * 0.020 + 1.3) * 0.03, 1.00 + sin(t * 0.018 + 0.8) * 0.02),
            SIMD2(1.00, 1.00),
        ]
    }

    private func meshColors() -> [Color] {
        [
            Color(white: 0.020),
            Color(white: 0.030),
            Color(white: 0.026),
            Color(white: 0.034),
            Color(white: 0.048),
            Color(white: 0.032),
            Color(white: 0.024),
            Color(white: 0.036),
            Color(white: 0.022),
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

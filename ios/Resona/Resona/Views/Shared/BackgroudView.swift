import SwiftUI

struct BackgroundView: View {
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [Color(white: 0.04), Color(white: 0.12)]
                : [Color(white: 0.95), Color(white: 0.85)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
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
        let moveSpeedX: CGFloat
        let moveSpeedY: CGFloat
    }

    init(starCount: Int = 100) {
        self.starCount = starCount
    }

    var body: some View {
        GeometryReader { _ in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(white: 0.04),
                        Color(white: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                // Draw twinkling and moving stars
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let time = timeline.date.timeIntervalSinceReferenceDate

                        // Draw stars
                        for star in stars {
                            // Use a sine wave to create a twinkling effect
                            let twinkle = sin(time * star.twinkleSpeed) * 0.3 + 0.7
                            let opacity = star.baseOpacity * twinkle

                            let rect = CGRect(
                                x: star.x * size.width - star.size / 2,
                                y: star.y * size.height - star.size / 2,
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
            generateStars()
            startStarAnimation()
        }
    }

    private func generateStars() {
        stars = (0 ..< starCount).map { _ in
            Star(
                x: CGFloat.random(in: -0.1...1.1),
                y: CGFloat.random(in: -0.1...1.1),
                size: CGFloat.random(in: 0.5...2.5),
                baseOpacity: CGFloat.random(in: 0.4...1.0),
                twinkleSpeed: Double.random(in: 2.5...6.0),
                moveSpeedX: CGFloat.random(in: -0.0001...0.0001),
                moveSpeedY: CGFloat.random(in: -0.0001...0.0001)
            )
        }
    }

    private func startStarAnimation() {
        // Continuously update star positions
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
            updateStars()
        }
    }

    private func updateStars() {
        for i in stars.indices {
            // Slowly move stars
            stars[i].x += stars[i].moveSpeedX
            stars[i].y += stars[i].moveSpeedY

            // If a star moves outside any edge, re-enter from the opposite edge
            if stars[i].y > 1.1 {
                stars[i].y = -0.1
                stars[i].x = CGFloat.random(in: -0.1...1.1)
            } else if stars[i].y < -0.1 {
                stars[i].y = 1.1
                stars[i].x = CGFloat.random(in: -0.1...1.1)
            }

            if stars[i].x > 1.1 {
                stars[i].x = -0.1
                stars[i].y = CGFloat.random(in: -0.1...1.1)
            } else if stars[i].x < -0.1 {
                stars[i].x = 1.1
                stars[i].y = CGFloat.random(in: -0.1...1.1)
            }
        }
    }
}

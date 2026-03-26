import SwiftUI

struct RippleBackground: View {
    @State private var time: Double = 0
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let t = timeline.date.timeIntervalSinceReferenceDate
                
                // 背景底色（灰白）
                let gradient = Gradient(colors: [
                    Color(white: 0.96),
                    Color(white: 0.92)
                ])
                
                context.fill(
                    Path(CGRect(origin: .zero, size: size)),
                    with: .linearGradient(
                        gradient,
                        startPoint: .zero,
                        endPoint: CGPoint(x: size.width, y: size.height)
                    )
                )
                
                // 生成“水波”路径
                var path = Path()
                
                let amplitude: CGFloat = 8   // 波动幅度（很小）
                let frequency: CGFloat = 0.01
                
                for y in stride(from: 0, to: size.height, by: 4) {
                    path.move(to: CGPoint(x: 0, y: y))
                    
                    for x in stride(from: 0, to: size.width, by: 4) {
                        let wave = sin(x * frequency + CGFloat(t) * 0.3)
                        let offset = wave * amplitude
                        
                        path.addLine(to: CGPoint(x: x, y: y + offset))
                    }
                }
                
                context.stroke(
                    path,
                    with: .color(Color.white.opacity(0.06)),
                    lineWidth: 1
                )
                
                // 高光（glimmer）
                let glow = sin(t * 0.5) * 0.5 + 0.5
                
                context.addFilter(.blur(radius: 8))
                context.opacity = 0.15 * glow
                
                context.fill(
                    Path(ellipseIn: CGRect(
                        x: size.width * 0.4,
                        y: size.height * 0.3,
                        width: 200,
                        height: 120
                    )),
                    with: .color(.white)
                )
            }
        }
        .ignoresSafeArea()
    }
}

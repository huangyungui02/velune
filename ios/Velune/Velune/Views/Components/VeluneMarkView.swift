import SwiftUI

struct VeluneMarkView: View {
    var baseColor: Color = .white
    var minimumOuterStroke: CGFloat = 1.5
    var minimumInnerStroke: CGFloat = 2.0

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            let outerDiameter = side * (720.0 / 1024.0)
            let innerDiameter = side * (400.0 / 1024.0)
            let outerStroke = max(minimumOuterStroke, side * (8.0 / 1024.0))
            let innerStroke = max(minimumInnerStroke, side * (16.0 / 1024.0))

            ZStack {
                Circle()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: baseColor.opacity(0.2), location: 0.0),
                                .init(color: baseColor.opacity(0.4), location: 0.5),
                                .init(color: baseColor.opacity(0.2), location: 1.0)
                            ],
                            startPoint: .topTrailing,
                            endPoint: .bottomLeading
                        ),
                        style: StrokeStyle(lineWidth: outerStroke)
                    )
                    .frame(width: outerDiameter, height: outerDiameter)

                Circle()
                    .stroke(
                        LinearGradient(
                            stops: [
                                .init(color: baseColor.opacity(0.8), location: 0.0),
                                .init(color: baseColor.opacity(0.4), location: 0.5),
                                .init(color: baseColor.opacity(0.8), location: 1.0)
                            ],
                            startPoint: .bottomTrailing,
                            endPoint: .topLeading
                        ),
                        style: StrokeStyle(lineWidth: innerStroke)
                    )
                    .frame(width: innerDiameter, height: innerDiameter)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
    }
}

import SwiftUI

struct GlimmerCardView: View {
    let content: String
    let isGenerating: Bool

    init(
        content: String,
        isGenerating: Bool = false
    ) {
        self.content = content
        self.isGenerating = isGenerating
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            if content.isEmpty && isGenerating {
                generatingRow
            } else {
                letterContent
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial.opacity(0.22),
            in: .rect(cornerRadius: 24, style: .continuous)
        )
        .background {
            RadialGradient(
                colors: [Color.white.opacity(0.04), .clear],
                center: .topLeading,
                startRadius: 0,
                endRadius: 300
            )
            .clipShape(.rect(cornerRadius: 24, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.04), .white.opacity(0.005)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
        .shadow(color: .black.opacity(0.24), radius: 24, x: 0, y: 12)
        .animation(.easeOut(duration: 0.16), value: content)
    }

    private var letterContent: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("“")
                .font(.system(size: 88, weight: .light, design: .serif))
                .foregroundStyle(Color.white.opacity(0.06))
                .frame(height: 24)
                .offset(x: -8, y: 16)

            GlimmerCardText(content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.bottom, 8)

            HStack {
                Spacer()
                Text("”")
                    .font(.system(size: 88, weight: .light, design: .serif))
                    .foregroundStyle(Color.white.opacity(0.06))
                    .frame(height: 24)
                    .offset(x: 8, y: -16)
            }
        }
    }

    private var generatingRow: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(UITheme.primaryText)

            Text("starsea.settlement.generating")
                .font(.subheadline)
                .foregroundStyle(UITheme.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GlimmerCardText: View {
    let content: String
    let foregroundStyle: AnyShapeStyle
    let font: Font
    let lineSpacing: CGFloat
    let tracking: CGFloat

    init(_ content: String) {
        self.init(content, foregroundStyle: UITheme.primaryText)
    }

    init(
        _ content: String,
        foregroundStyle: some ShapeStyle,
        font: Font = .system(size: 17, weight: .light, design: .serif),
        lineSpacing: CGFloat = 10,
        tracking: CGFloat = 0.8
    ) {
        self.content = content
        self.foregroundStyle = AnyShapeStyle(foregroundStyle)
        self.font = font
        self.lineSpacing = lineSpacing
        self.tracking = tracking
    }

    var body: some View {
        Text(content)
            .font(font)
            .lineSpacing(lineSpacing)
            .tracking(tracking)
            .multilineTextAlignment(.leading)
            .foregroundStyle(foregroundStyle)
    }
}

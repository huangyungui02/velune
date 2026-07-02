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
                diaryContent
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
        .background(
            .ultraThinMaterial.opacity(0.14),
            in: .rect(cornerRadius: 16, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 0.8)
        }
        .shadow(color: .black.opacity(0.34), radius: 28, y: 18)
        .animation(.easeOut(duration: 0.16), value: content)
    }

    private var diaryContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 14, weight: .light))
                    .foregroundStyle(UITheme.secondaryText.opacity(0.88))
                
                Text(String(localized: "starsea.settlement.diaryTitle"))
                    .font(.system(size: 14, weight: .light, design: .serif))
                    .foregroundStyle(UITheme.secondaryText.opacity(0.88))
                    .tracking(1.5)
                
                Spacer()
            }
            
            Rectangle()
                .fill(Color.white.opacity(0.09))
                .frame(height: 0.5)
            
            GlimmerCardText(content)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 4)
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
            .fixedSize(horizontal: false, vertical: true)
    }
}

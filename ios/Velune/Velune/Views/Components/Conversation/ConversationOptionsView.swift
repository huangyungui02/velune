import SwiftUI

struct ConversationOptionsView: View {
    let options: [String]
    let isDisabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    onSelect(option)
                } label: {
                    Text(option)
                        .font(.system(size: 14, weight: .regular))
                        .fontDesign(.serif)
                        .tracking(0.3)
                        .lineSpacing(5)
                        .foregroundStyle(UITheme.primaryText.opacity(isDisabled ? 0.36 : 0.85))
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)
                        .contentShape(.rect)
                }
                .buttonStyle(ElegantOptionButtonStyle(isDisabled: isDisabled))
                .disabled(isDisabled)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct ElegantOptionButtonStyle: ButtonStyle {
    let isDisabled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                Color.white.opacity(0.04),
                in: .rect(cornerRadius: 16)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        Color.white.opacity(0.05),
                        lineWidth: 0.5
                    )
            }
            .opacity(1.0)
    }
}

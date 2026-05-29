import SwiftUI

struct ConversationOptionsView: View {
    let options: [String]
    let isDisabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
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
                        .padding(.vertical, 13)
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
                configuration.isPressed
                ? AnyShapeStyle(
                    LinearGradient(
                        colors: [
                            UITheme.glimmerGlow.opacity(0.08),
                            Color(red: 0.07, green: 0.075, blue: 0.095).opacity(0.35)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                : AnyShapeStyle(
                    Color(red: 0.06, green: 0.065, blue: 0.085)
                        .opacity(0.24)
                ),
                in: .rect(cornerRadius: 14)
            )
            .glassEffect(in: .rect(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(
                        configuration.isPressed ? UITheme.glimmerGlow.opacity(0.12) : .white.opacity(0.04),
                        lineWidth: 0.5
                    )
            }
            .scaleEffect(configuration.isPressed ? 0.99 : 1.0)
            .animation(.spring(response: 0.28, dampingFraction: 0.75), value: configuration.isPressed)
    }
}

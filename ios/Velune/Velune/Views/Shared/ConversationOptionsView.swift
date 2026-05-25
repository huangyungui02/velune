import SwiftUI

struct ConversationOptionsView: View {
    let options: [String]
    let isDisabled: Bool
    let onSelect: (String) -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    onSelect(option)
                } label: {
                    HStack(spacing: 12) {
                        Text(option)
                            .font(.system(size: 13, weight: .regular))
                            .tracking(1.4)
                            .foregroundStyle(UITheme.primaryText.opacity(isDisabled ? 0.36 : 0.76))
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .light))
                            .foregroundStyle(UITheme.primaryText.opacity(isDisabled ? 0.16 : 0.28))
                    }
                    .padding(.horizontal, 18)
                    .padding(.vertical, 15)
                    .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(isDisabled)

                if index < options.count - 1 {
                    Divider()
                        .overlay(.white.opacity(0.05))
                        .padding(.leading, 18)
                }
            }
        }
        .background(Color(red: 0.07, green: 0.075, blue: 0.095).opacity(0.28), in: .rect(cornerRadius: 18))
        .glassEffect(in: .rect(cornerRadius: 18))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.06), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.20), radius: 18, y: 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

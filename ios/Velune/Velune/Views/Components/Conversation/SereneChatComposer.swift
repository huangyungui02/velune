import SwiftUI

struct SereneChatComposer: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    let isBusy: Bool
    let canSend: Bool
    let placeholderKey: LocalizedStringKey
    let onSend: () async -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            TextField(placeholderKey, text: $text, axis: .vertical)
                .focused(isFocused)
                .lineLimit(1 ... 3)
                .textFieldStyle(.plain)
                .font(.callout)
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)
                .submitLabel(.send)
                .padding(.leading, 18)
                .padding(.vertical, 13)

            Button {
                Task { await onSend() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(canSend ? Color(red: 0.03, green: 0.035, blue: 0.055) : UITheme.primaryText.opacity(0.24))
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .fill(canSend ? Color.white : Color.clear)
                    )
                    .overlay {
                        if !canSend {
                            Circle()
                                .strokeBorder(.white.opacity(0.06), lineWidth: 0.5)
                        }
                    }
            }
            .disabled(!canSend)
            .scaleEffect(canSend ? 1.0 : 0.88)
            .padding(.trailing, 8)
            .animation(.spring(response: 0.25, dampingFraction: 0.7), value: canSend)
        }
        .frame(minHeight: 46)
        .background(Color(red: 0.03, green: 0.035, blue: 0.055).opacity(0.60), in: .capsule)
        .glassEffect(in: .capsule)
        .overlay {
            Capsule()
                .stroke(.white.opacity(isFocused.wrappedValue ? 0.15 : 0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .disabled(isBusy)
        .opacity(isBusy ? 0.40 : 1.0)
        .animation(.easeOut(duration: 0.22), value: isBusy)
    }
}

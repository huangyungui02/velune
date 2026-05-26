import SwiftUI

struct StarSeaConversationComposer: View {
    @Binding var text: String
    let isFocused: FocusState<Bool>.Binding
    let isBusy: Bool
    let canSend: Bool
    let reduceMotion: Bool
    let onSend: () async -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            TextField("starsea.chat.placeholder", text: $text, axis: .vertical)
                .focused(isFocused)
                .lineLimit(1 ... 4)
                .textFieldStyle(.plain)
                .font(.footnote)
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)
                .submitLabel(.send)
                .padding(.leading, 18)
                .padding(.vertical, 13)

            Button {
                Task { await onSend() }
            } label: {
                sendButtonContent
            }
            .disabled(!canSend)
            .scaleEffect(canSend ? 1 : 0.94)
            .padding(.trailing, 8)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canSend)
        }
        .frame(minHeight: 46)
        .background(Color(red: 0.03, green: 0.035, blue: 0.055).opacity(0.60), in: .capsule)
        .glassEffect(in: .capsule)
        .overlay {
            Capsule()
                .stroke(.white.opacity(isFocused.wrappedValue ? 0.15 : 0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
        .padding(.horizontal, 20)
        .padding(.top, 10)
        .padding(.bottom, 16)
    }

    @ViewBuilder
    private var sendButtonContent: some View {
        if isBusy {
            ProgressView()
                .tint(UITheme.primaryText.opacity(0.8))
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.06), in: .circle)
        } else {
            Image(systemName: "arrow.up")
                .font(.body.weight(.semibold))
                .foregroundStyle(canSend ? UITheme.primaryText : UITheme.primaryText.opacity(0.24))
                .frame(width: 32, height: 32)
                .background(.white.opacity(canSend ? 0.08 : 0.02), in: .circle)
        }
    }
}

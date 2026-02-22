import MarkdownUI
import SwiftUI

struct ResonanceChatView: View {
    let soulerId: UUID
    let soulerName: String

    @State private var messages: [ResonanceMessage] = []
    @State private var inputText = ""
    @State private var isLoading = false
    @State private var isSending = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 0) {
                if isLoading, messages.isEmpty {
                    ProgressView(String(localized: "common.loading"))
                        .tint(UITheme.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if messages.isEmpty {
                    EmptyView(title: String(localized: "resonance.chat.empty"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    messageList
                }

                composer
            }
        }
        .navigationTitle(soulerName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    SoulerView(soulerId: soulerId)
                } label: {
                    Image(systemName: "person.text.rectangle")
                }
                .accessibilityLabel(String(localized: "resonance.chat.action.profile"))
            }
        }
        .alert(String(localized: "matching.error.title"), isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button(String(localized: "common.ok"), role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "matching.error.unknown"))
        }
        .task {
            await loadMessages()
        }
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ResonanceChatBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .refreshable {
                await loadMessages()
            }
            .onChange(of: messages.count) { _, _ in
                guard let lastId = messages.last?.id else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo(lastId, anchor: .bottom)
                }
            }
            .onChange(of: messages.last?.content) { _, _ in
                guard let lastId = messages.last?.id else { return }
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(
                String(localized: "resonance.chat.placeholder"),
                text: $inputText,
                axis: .vertical
            )
            .lineLimit(1 ... 4)
            .textFieldStyle(.plain)
            .font(UITheme.literary(size: 17))
            .foregroundStyle(UITheme.primaryText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(.white.opacity(0.08), in: .rect(cornerRadius: 14))

            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 30, weight: .regular, design: .rounded))
                    .foregroundStyle(UITheme.primaryText)
            }
            .disabled(isSending || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            .opacity(isSending || inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.4 : 1.0)
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    @MainActor
    private func loadMessages() async {
        if isLoading { return }

        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await ResonanceMessage.getHistory(soulerId: soulerId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func sendMessage() async {
        if isSending { return }

        let content = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !content.isEmpty else { return }

        isSending = true
        inputText = ""
        defer { isSending = false }

        let userLocal = ResonanceMessage(
            id: UUID(),
            soulerId: soulerId,
            role: .user,
            content: content,
            createdAt: .now
        )
        messages.append(userLocal)

        let assistantLocalId = UUID()
        let assistantLocal = ResonanceMessage(
            id: assistantLocalId,
            soulerId: soulerId,
            role: .assistant,
            content: "",
            createdAt: .now
        )
        messages.append(assistantLocal)

        do {
            for try await event in ResonanceMessage.streamReply(soulerId: soulerId, content: content) {
                switch event {
                case let .delta(delta):
                    if let index = messages.firstIndex(where: { $0.id == assistantLocalId }) {
                        messages[index].content += delta
                    }
                case .done:
                    break
                }
            }
            messages = try await ResonanceMessage.getHistory(soulerId: soulerId)
        } catch {
            messages.removeAll { $0.id == assistantLocalId }
            errorMessage = error.localizedDescription
        }
    }
}

private struct ResonanceChatBubble: View {
    let message: ResonanceMessage

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 32)
            }

            Markdown(message.content)
                .markdownTextStyle {
                    FontFamily(.custom(UITheme.literaryFontName))
                    FontSize(17)
                    ForegroundColor(UITheme.primaryText)
                }
                .lineSpacing(5)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isUser
                        ? .white.opacity(0.16)
                        : .white.opacity(0.08),
                    in: .rect(cornerRadius: 14)
                )
                .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)

            if !isUser {
                Spacer(minLength: 32)
            }
        }
    }
}

#Preview {
    NavigationStack {
        ResonanceChatView(
            soulerId: UUID(),
            soulerName: "Socrates"
        )
    }
}

import SwiftUI

struct StarSeaConversationMessageList: View {
    let messages: [StarSeaMessage]
    let resonanceMatches: [StarSeaStreamService.ResonanceMatch]
    let isOptionsDisabled: Bool
    let onDismissComposerFocus: () -> Void
    let onSelectOption: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    let lastMessageId = messages.last?.id

                    ForEach(messages) { message in
                        messageRow(message, lastMessageId: lastMessageId)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(.rect)
            .onTapGesture(perform: onDismissComposerFocus)
            .onChange(of: messages.count) { _, _ in
                scrollToLatest(with: proxy, animated: true)
            }
            .onChange(of: messages.last?.content) { _, _ in
                scrollToLatest(with: proxy, animated: false)
            }
            .onChange(of: resonanceMatches) { _, _ in
                scrollToLatest(with: proxy, animated: true)
            }
        }
    }

    private func messageRow(_ message: StarSeaMessage, lastMessageId: UUID?) -> some View {
        VStack(spacing: 8) {
            let payload = payload(for: message)

            if shouldShowResonanceMatches(for: message, lastMessageId: lastMessageId) {
                StarSeaResonanceMatchesView(matches: resonanceMatches)
                    .padding(.bottom, 2)
            }

            ConversationMessageRow(
                role: message.role == .user ? .user : .assistant,
                content: payload.body
            )

            if message.id == lastMessageId, !payload.options.isEmpty {
                ConversationOptionsView(
                    options: payload.options,
                    isDisabled: isOptionsDisabled,
                    onSelect: onSelectOption
                )
                .padding(.top, 2)
            }
        }
    }

    private func payload(for message: StarSeaMessage) -> ConversationOptionPayload {
        guard message.role == .assistant else {
            return ConversationOptionPayload(body: message.content, options: [])
        }

        return ConversationOptionParser.parse(message.content)
    }

    private func shouldShowResonanceMatches(for message: StarSeaMessage, lastMessageId: UUID?) -> Bool {
        message.role == .assistant
            && message.id == lastMessageId
            && !resonanceMatches.isEmpty
    }

    private func scrollToLatest(with proxy: ScrollViewProxy, animated: Bool) {
        guard let target = messages.last?.id else { return }

        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}

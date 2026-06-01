import SwiftUI

struct StarSeaConversationMessageList: View {
    let events: [StarSeaTimelineEvent]
    let isOptionsDisabled: Bool
    let isStreaming: Bool
    @Binding var shouldPauseAutoScrollDuringStreaming: Bool
    var showsOptions = true
    let onDismissComposerFocus: () -> Void
    let onSelectOption: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    let lastAssistantMessageId = events.lastAssistantMessage?.id

                    ForEach(events) { event in
                        eventRow(event, lastAssistantMessageId: lastAssistantMessageId)
                            .id(event.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 10)
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(.rect)
            .onTapGesture(perform: onDismissComposerFocus)
            .onChange(of: events.count) { _, _ in
                scrollToLatest(with: proxy, animated: true, reason: .countChanged)
            }
            .onChange(of: events.lastMessageContent) { _, _ in
                scrollToLatest(with: proxy, animated: false, reason: .contentChanged)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if isStreaming {
                            shouldPauseAutoScrollDuringStreaming = true
                        }
                    }
            )
        }
    }

    @ViewBuilder
    private func eventRow(_ event: StarSeaTimelineEvent, lastAssistantMessageId: UUID?) -> some View {
        switch event {
        case let .message(message):
            messageRow(message, lastAssistantMessageId: lastAssistantMessageId)
        case let .resonanceMatches(_, matches):
            StarSeaResonanceMatchesView(matches: matches)
                .padding(.vertical, 2)
        }
    }

    private func messageRow(_ message: StarSeaMessage, lastAssistantMessageId: UUID?) -> some View {
        let payload = payload(for: message)
        let hasInlineOptions = showsOptions
            && message.id == lastAssistantMessageId
            && !payload.options.isEmpty

        return VStack(spacing: 8) {
            ConversationMessageRow(
                role: message.role == .user ? .user : .assistant,
                content: payload.body
            )

            if hasInlineOptions {
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

    private enum ScrollTrigger {
        case countChanged
        case contentChanged
    }

    private func scrollToLatest(with proxy: ScrollViewProxy, animated: Bool, reason: ScrollTrigger? = nil) {
        if isStreaming, shouldPauseAutoScrollDuringStreaming, reason != nil {
            return
        }

        guard let target = events.last?.id else { return }

        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(target, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(target, anchor: .bottom)
        }
    }
}

private extension [StarSeaTimelineEvent] {
    var lastAssistantMessage: StarSeaMessage? {
        reversed().compactMap(\.message).first { $0.role == .assistant }
    }

    var lastMessageContent: String? {
        reversed().compactMap(\.message).first?.content
    }
}

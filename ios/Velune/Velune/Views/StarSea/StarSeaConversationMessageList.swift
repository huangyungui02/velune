import SwiftUI

struct StarSeaConversationMessageList: View {
    let events: [StarSeaTimelineEvent]
    let isOptionsDisabled: Bool
    let isStreaming: Bool
    let isAwaitingResponse: Bool
    @Binding var shouldPauseAutoScrollDuringStreaming: Bool
    var showsOptions = true
    let onDismissComposerFocus: () -> Void
    let onSelectOption: (String) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    let lastVisibleMessageId = events.last?.message?.id

                    ForEach(events) { event in
                        eventRow(event, lastVisibleMessageId: lastVisibleMessageId)
                            .id(event.id)
                    }

                    if isAwaitingResponse {
                        StarlightWaitingPlaceholderView()
                            .id("waiting-placeholder")
                            .transition(.opacity.combined(with: .scale(scale: 0.95)))
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
            .onChange(of: isAwaitingResponse) { _, newValue in
                if newValue {
                    withAnimation(.easeOut(duration: 0.25)) {
                        proxy.scrollTo("waiting-placeholder", anchor: .bottom)
                    }
                }
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
    private func eventRow(_ event: StarSeaTimelineEvent, lastVisibleMessageId: UUID?) -> some View {
        switch event {
        case let .message(message):
            messageRow(message, lastVisibleMessageId: lastVisibleMessageId)
        case let .resonanceMatches(_, matches):
            StarSeaResonanceMatchesView(matches: matches)
                .padding(.vertical, 2)
        case let .divinationResult(_, divination):
            ChatDivinationCardView(divination: divination)
                .padding(.vertical, 4)
        }
    }

    private func messageRow(_ message: StarSeaMessage, lastVisibleMessageId: UUID?) -> some View {
        let payload = payload(for: message)
        let hasInlineOptions = showsOptions
            && message.id == lastVisibleMessageId
            && !payload.options.isEmpty

        return VStack(spacing: 8) {
            if message.displayType == .thinking || message.displayType == .thinkingSummary {
                StarSeaThinkingMessageView(
                    content: payload.body,
                    durationSeconds: message.thinkingDurationSeconds
                )
            } else {
                ConversationMessageRow(
                    role: message.role == .user ? .user : .assistant,
                    content: payload.body
                )
            }

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

        if isAwaitingResponse {
            if animated {
                withAnimation(.easeOut(duration: 0.2)) {
                    proxy.scrollTo("waiting-placeholder", anchor: .bottom)
                }
            } else {
                proxy.scrollTo("waiting-placeholder", anchor: .bottom)
            }
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

private struct StarSeaThinkingMessageView: View {
    let content: String
    let durationSeconds: Int?

    var body: some View {
        HStack(alignment: .top) {
            if let durationSeconds {
                Text(thoughtDurationText(durationSeconds))
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(UITheme.primaryText.opacity(0.42))
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        Text(content)
                            .font(.system(size: 12, weight: .regular))
                            .lineSpacing(4)
                            .foregroundStyle(UITheme.primaryText.opacity(0.42))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.trailing, 4)

                        Color.clear
                            .frame(height: 1)
                            .id("thinking-bottom")
                    }
                    .scrollIndicators(.hidden)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: 96, alignment: .top)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(UITheme.primaryText.opacity(0.035), in: .rect(cornerRadius: 10))
                    .onChange(of: content) { _, _ in
                        proxy.scrollTo("thinking-bottom", anchor: .bottom)
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func thoughtDurationText(_ seconds: Int) -> String {
        let format = NSLocalizedString("starsea.thinking.finished", comment: "")
        return String.localizedStringWithFormat(format, seconds)
    }
}

private extension [StarSeaTimelineEvent] {
    var lastMessageContent: String? {
        reversed().compactMap(\.message).first?.content
    }
}

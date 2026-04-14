import SwiftUI
import MarkdownUI

extension ChatView {
    @ViewBuilder
    var emptyConversationView: some View {
        if isLoadingChapters {
            ProgressView()
                .tint(UITheme.primaryText)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if chapters.isEmpty {
            chapterUnavailableView
        } else {
            ScrollView {
                chapterPanel
                    .padding(.horizontal)
                    .padding(.top, 12)
                    .padding(.bottom, 16)
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }

    var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    let lastMessageId = messages.last?.id
                    let inlineOptions = inlineChapterOptions

                    ForEach(messages) { message in
                        VStack(spacing: 8) {
                            ChatBubble(
                                message: message,
                                content: visibleContent(for: message)
                            )

                            if message.id == lastMessageId, !inlineOptions.isEmpty {
                                chapterOptionsInlineView(options: inlineOptions)
                            }
                        }
                        .id(message.id)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .contentShape(.rect)
            .onTapGesture(perform: dismissComposer)
            .onAppear {
                guard !hasScrolledToLatestOnAppear else { return }
                hasScrolledToLatestOnAppear = true
                scrollToLatest(with: proxy, animated: false)
            }
            .onChange(of: messages.count) { _, _ in
                scrollToLatest(with: proxy, animated: true, reason: .countChanged)
            }
            .onChange(of: messages.last?.content) { _, _ in
                scrollToLatest(with: proxy, animated: false, reason: .contentChanged)
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { _ in
                        if isSending {
                            shouldPauseAutoScrollDuringStreaming = true
                        }
                    }
            )
        }
    }

    @ViewBuilder
    var composer: some View {
        if let chapter = selectedChapter {
            HStack(spacing: 12) {
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        self.selectedChapter = nil
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self.isComposerFocused = true
                    }
                } label: {
                    Text("resonance.chat.chapters.action.freeChat")
                        .font(.body)
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.primaryText)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .strokeBorder(.white.opacity(0.1), lineWidth: 0.5)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isStartingChapterSession)

                Button {
                    let selected = chapter
                    withAnimation {
                        self.selectedChapter = nil
                    }
                    Task {
                        await startChapterSession(selected)
                    }
                } label: {
                    HStack(spacing: 6) {
                        if isStartingChapterSession {
                            ProgressView().tint(.black)
                        } else {
                            Text("resonance.chat.chapters.action.start")
                        }
                    }
                    .font(.body.weight(.medium))
                    .fontDesign(.serif)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(UITheme.primaryText, in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(isStartingChapterSession)
            }
            .padding()
            .transition(.move(edge: .bottom).combined(with: .opacity))
        } else {
            let canSend = !isSending
                && !isStartingChapterSession
                && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            HStack(alignment: .bottom, spacing: 6) {
                TextField(
                    "resonance.chat.placeholder",
                    text: $inputText,
                    axis: .vertical
                )
                .focused($isComposerFocused)
                .lineLimit(1 ... 4)
                .textFieldStyle(.plain)
                .font(.body)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)
                .padding(.leading, 16)
                .padding(.trailing, 4)
                .padding(.vertical, 14)

                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.black)
                        .frame(width: 36, height: 36)
                        .background(.white, in: .circle)
                }
                .disabled(!canSend)
                .opacity(canSend ? 1.0 : 0.4)
                .scaleEffect(canSend ? 1 : 0.94)
                .padding(.trailing, 6)
                .padding(.bottom, 6)
                .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canSend)
            }
            .background(Color.clear, in: .rect(cornerRadius: 24))
            .glassEffect(in: .rect(cornerRadius: 24))
            .padding()
            .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isSending)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    var chapterPanel: some View {
        VStack(alignment: .leading, spacing: 20) {
            chapterListView
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    func chapterOptionsInlineView(options: [String]) -> some View {
        HStack {
            chapterOptionsView(options: options)
                .frame(maxWidth: 320, alignment: .leading)
            Spacer(minLength: 32)
        }
    }

    func chapterOptionsView(options: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                Button {
                    Task {
                        await sendMessage(prefilledContent: option)
                    }
                } label: {
                    Text(option)
                        .font(.footnote)
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.primaryText)
                        .lineLimit(2)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .disabled(isSending || isLoading)
            }
        }
    }

    private var chapterUnavailableView: some View {
        ContentUnavailableView {
            Label("resonance.chat.empty", systemImage: "sparkles")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chapterListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(chapters) { chapter in
                let isSelected = selectedChapter?.id == chapter.id
                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        if isSelected {
                            selectedChapter = nil
                        } else {
                            selectedChapter = chapter
                        }
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(chapter.title)
                            .font(.body.weight(isSelected ? .semibold : .medium))
                            .fontDesign(.serif)
                            .foregroundStyle(UITheme.primaryText)
                            .lineLimit(1)

                        Text(chapter.subtitle)
                            .font(.footnote)
                            .fontDesign(.serif)
                            .foregroundStyle(UITheme.secondaryText)
                            .lineLimit(2)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        isSelected ? .white.opacity(0.12) : .white.opacity(0.04),
                        in: .rect(cornerRadius: 16)
                    )
                    .overlay {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.2), lineWidth: 0.5)
                        } else {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(.white.opacity(0.05), lineWidth: 0.5)
                        }
                    }
                }
                .buttonStyle(.plain)
                .disabled(isSending || isStartingChapterSession)
            }
        }
    }

    private enum ScrollTrigger {
        case countChanged
        case contentChanged
    }

    private func scrollToLatest(with proxy: ScrollViewProxy, animated: Bool, reason: ScrollTrigger? = nil) {
        if isSending, shouldPauseAutoScrollDuringStreaming, reason != nil {
            return
        }

        guard let lastId = messages.last?.id else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        } else {
            proxy.scrollTo(lastId, anchor: .bottom)
        }
    }
}

private struct ChatBubble: View {
    let message: Message
    let content: String

    private var isUser: Bool {
        message.role == .user
    }

    var body: some View {
        HStack {
            if isUser {
                Spacer(minLength: 32)
            }

            Group {
                if !isUser && content.isEmpty {
                    MatchingWaveIcon(
                        ringSize: 10,
                        containerSize: 22,
                        color: UITheme.primaryText.opacity(0.6)
                    )
                } else {
                    Markdown(content)
                        .veluneMarkdownBodyStyle()
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                isUser
                    ? .white.opacity(0.12)
                    : .white.opacity(0.06),
                in: .rect(cornerRadius: 16)
            )
                .frame(maxWidth: 320, alignment: isUser ? .trailing : .leading)

            if !isUser {
                Spacer(minLength: 32)
            }
        }
    }
}

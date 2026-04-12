import SwiftUI
import MarkdownUI

extension ChatView {
    var emptyConversationView: some View {
        ScrollView {
            chapterPanel
                .padding(.horizontal)
                .padding(.top, 12)
                .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
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

    var composer: some View {
        let canSend = !isSending
            && !isStartingChapterSession
            && !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return HStack(alignment: .bottom, spacing: 10) {
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
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.clear, in: .rect(cornerRadius: 16))
            .glassEffect(in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(isComposerFocused ? 0.18 : 0.10), lineWidth: 0.8)
            }
            .shadow(color: .black.opacity(0.10), radius: 14, y: 2)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isComposerFocused)

            Button {
                Task {
                    await sendMessage()
                }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(canSend ? UITheme.primaryText : UITheme.tertiaryText)
                    .frame(width: 45, height: 45)
                    .background(Color.clear, in: .circle)
                    .glassEffect(in: .circle)
                    .overlay {
                        Circle()
                            .strokeBorder(.white.opacity(canSend ? 0.16 : 0.08), lineWidth: 0.8)
                    }
                    .shadow(color: .black.opacity(canSend ? 0.12 : 0.08), radius: 12, y: 2)
            }
            .disabled(!canSend)
            .scaleEffect(canSend ? 1 : 0.94)
            .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: canSend)
        }
        .padding()
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isSending)
    }

    var chapterPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("resonance.chat.chapters.title")
                .font(.headline.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)

            if isLoadingChapters && chapterState == nil {
                HStack(spacing: 10) {
                    ProgressView()
                        .tint(UITheme.primaryText)
                    Text("common.loading")
                        .font(.footnote)
                        .foregroundStyle(UITheme.secondaryText)
                }
            } else if let chapterState {
                switch chapterState.status {
                case .pending:
                    chapterPendingView
                case .processing:
                    chapterProcessingView
                case .failed:
                    chapterFailedView(error: chapterState.error)
                case .complete:
                    chapterListView(chapters: chapterState.chapters)
                }
            } else {
                chapterPendingView
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.white.opacity(0.08), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 0.9)
        }
        .glassEffect(in: .rect(cornerRadius: 16))
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
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(.white.opacity(0.16), lineWidth: 0.8)
                        }
                }
                .buttonStyle(.plain)
                .disabled(isSending || isLoading)
            }
        }
    }

    private var chapterPendingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("resonance.chat.chapters.pending")
                .font(.footnote)
                .foregroundStyle(UITheme.secondaryText)

            Button {
                Task {
                    await generateChapters()
                }
            } label: {
                Text("resonance.chat.chapters.generate")
                    .font(.footnote.weight(.semibold))
                    .fontDesign(.serif)
                    .foregroundStyle(UITheme.primaryText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(.white.opacity(0.12), in: .capsule)
                    .overlay {
                        Capsule()
                            .stroke(.white.opacity(0.2), lineWidth: 0.8)
                    }
            }
            .buttonStyle(.plain)
            .disabled(isTriggeringChapterGeneration)
        }
    }

    private var chapterProcessingView: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                ProgressView()
                    .tint(UITheme.primaryText)
                Text("resonance.chat.chapters.processing")
                    .font(.footnote)
                    .foregroundStyle(UITheme.secondaryText)
            }
        }
    }

    private func chapterFailedView(error: String?) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("resonance.chat.chapters.failed")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(UITheme.primaryText)

            if let error, !error.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(UITheme.secondaryText)
                    .lineLimit(3)
            }

            Button {
                Task {
                    await generateChapters()
                }
            } label: {
                Text("resonance.chat.chapters.retry")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(UITheme.primaryText)
            }
            .buttonStyle(.plain)
            .disabled(isTriggeringChapterGeneration)
        }
    }

    private func chapterListView(chapters: [SoulerChapter]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if chapters.isEmpty {
                Text("resonance.chat.chapters.pending")
                    .font(.footnote)
                    .foregroundStyle(UITheme.secondaryText)
            } else {
                ForEach(chapters) { chapter in
                    Button {
                        Task {
                            await startChapterSession(chapter)
                        }
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(chapter.title)
                                .font(.body.weight(.medium))
                                .fontDesign(.serif)
                                .foregroundStyle(UITheme.primaryText)
                                .lineLimit(1)

                            Text(chapter.subtitle)
                                .font(.footnote)
                                .fontDesign(.serif)
                                .foregroundStyle(UITheme.secondaryText)
                                .lineLimit(2)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(.white.opacity(0.08), in: .rect(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                    .disabled(isSending || isTriggeringChapterGeneration || isStartingChapterSession)
                }
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

            Markdown(content)
                .markdownTextStyle {
                    ForegroundColor(UITheme.primaryText)
                }
                .fontDesign(.serif)
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

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
                            ConversationMessageRow(
                                role: message.role == .user ? .user : .assistant,
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

            HStack(alignment: .center, spacing: 10) {
                TextField(
                    "resonance.chat.placeholder",
                    text: $inputText,
                    axis: .vertical
                )
                .focused($isComposerFocused)
                .lineLimit(1 ... 4)
                .textFieldStyle(.plain)
                .font(.footnote)
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)
                .submitLabel(.send)
                .padding(.leading, 18)
                .padding(.vertical, 13)

                Button {
                    Task {
                        await sendMessage()
                    }
                } label: {
                    if isSending || isStartingChapterSession {
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
                    .stroke(.white.opacity(isComposerFocused ? 0.15 : 0.08), lineWidth: 0.5)
            }
            .shadow(color: .black.opacity(0.45), radius: 24, y: 10)
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 16)
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
        chapterOptionsView(options: options)
            .padding(.top, 2)
    }

    func chapterOptionsView(options: [String]) -> some View {
        ConversationOptionsView(
            options: options,
            isDisabled: isSending || isLoading
        ) { option in
            selectConversationOption(option)
        }
    }

    func selectConversationOption(_ option: String) {
        inputText = option
        isComposerFocused = true
    }

    private var chapterUnavailableView: some View {
        ContentUnavailableView {
            Label("resonance.chat.empty", systemImage: "sparkles")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var chapterListView: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(chapters.enumerated()), id: \.element.id) { index, chapter in
                let isSelected = selectedChapter?.id == chapter.id
                let isLocked = isChapterLocked(at: index)
                Button {
                    if isLocked {
                        isShowingPaywall = true
                        return
                    }

                    withAnimation(.easeOut(duration: 0.2)) {
                        if isSelected {
                            selectedChapter = nil
                        } else {
                            selectedChapter = chapter
                        }
                    }
                } label: {
                    ZStack(alignment: .trailing) {
                        if isLocked {
                            Image(systemName: "lock")
                                .font(.system(size: 54, weight: .ultraLight))
                                .foregroundStyle(UITheme.primaryText.opacity(0.08))
                                .padding(.trailing, 18)
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 8) {
                                Text(chapter.title)
                                    .font(.body.weight(isSelected ? .semibold : .medium))
                                    .fontDesign(.serif)
                                    .foregroundStyle(isLocked ? UITheme.primaryText.opacity(0.72) : UITheme.primaryText)
                                    .lineLimit(1)

                                if isLocked {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2.weight(.medium))
                                        .foregroundStyle(UITheme.secondaryText.opacity(0.7))
                                }
                            }

                            Text(chapter.subtitle)
                                .font(.footnote)
                                .fontDesign(.serif)
                                .foregroundStyle(isLocked ? UITheme.secondaryText.opacity(0.72) : UITheme.secondaryText)
                                .lineLimit(2)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        isSelected ? .white.opacity(0.12) : .white.opacity(isLocked ? 0.03 : 0.04),
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
                .disabled(!isLocked && (isSending || isStartingChapterSession))
            }
        }
    }

    private func isChapterLocked(at index: Int) -> Bool {
        index > 0 && !subscriptionManager.isPremium
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

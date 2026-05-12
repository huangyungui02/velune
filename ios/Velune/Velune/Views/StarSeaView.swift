import Supabase
import SwiftData
import SwiftUI

struct StarSeaView: View {
    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var isMatchingPresented = false
    @State private var manager = MatchingManager.shared
    @State private var showError = false
    @State private var showPaywall = false
    @State private var shouldRecoverToVerseAfterError = false
    @State private var currentPage: CardID? = .glimmer
    @State private var chatRoute: EchoChatRoute?
    @State private var isComposerPresented = false
    @Binding var composeRequestID: Int

    init(composeRequestID: Binding<Int> = .constant(0)) {
        _composeRequestID = composeRequestID
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    draftToolbarContent
                }
                .navigationDestination(isPresented: $isMatchingPresented) {
                    MatchingView(
                        manager: manager,
                        currentPage: $currentPage,
                        chatRoute: $chatRoute,
                        onClose: closeCurrentGlimmer
                    )
                    .toolbar(.hidden, for: .tabBar)
                }
                .navigationDestination(item: $chatRoute) { route in
                    ChatView(
                        sessionId: route.sessionId,
                        echoId: route.sessionId == nil ? route.echoId : nil,
                        draftPrelude: route.draftPrelude,
                        soulerId: route.soulerId,
                        soulerName: route.soulerName,
                        focusComposerOnAppear: true
                    )
                    .toolbar(.hidden, for: .tabBar)
                }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .fullScreenCover(isPresented: $isComposerPresented) {
            StarSeaComposerCover(
                text: $text,
                onDismiss: dismissComposer,
                onSend: send
            )
        }
        .onChange(of: manager.errorMessage) { _, newValue in
            if isMatchingPresented, newValue != nil {
                shouldRecoverToVerseAfterError = true
            }
            showError = newValue != nil
        }
        .onChange(of: showError) { _, isShowing in
            if !isShowing, shouldRecoverToVerseAfterError {
                recoverToVerseAfterError()
            }
        }
        .onChange(of: composeRequestID) { _, _ in
            if manager.isMatching {
                isMatchingPresented = true
            } else {
                isMatchingPresented = false
                presentComposer()
            }
        }
        .alert("matching.error.title", isPresented: $showError) {
            if manager.billingErrorContext?.shouldOfferUpgrade == true {
                Button("billing.action.openPaywall") {
                    showPaywall = true
                }
            }
            Button("common.ok", role: .cancel) {
                recoverToVerseAfterError()
            }
        } message: {
            if let errorMessage = manager.errorMessage {
                Text(errorMessage)
            } else {
                Text("matching.error.unknown")
            }
        }
    }

    private var mainContent: some View {
        ZStack {
            StarryBackgroundView()
                .contentShape(Rectangle())

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    if hasDraft {
                        DraftGlimmerCard(content: text) {
                            presentComposer()
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        HeroVerse()
                            .padding(.horizontal, 32)
                            .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.22), value: text.isEmpty)

            if !hasDraft {
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FloatingWriteButton {
                            presentComposer()
                        }
                        .padding(.trailing, 28)
                        .padding(.bottom, 40)
                    }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)).combined(with: .move(edge: .bottom)))
            }
        }
    }

    private var hasDraft: Bool {
        !text.isEmpty
    }

    @ToolbarContentBuilder
    private var draftToolbarContent: some ToolbarContent {
        if hasDraft {
            ToolbarItem(placement: .topBarLeading) {
                Button(role: .destructive, action: clearComposer) {
                    Image(systemName: "xmark")
                        .font(.body.weight(.medium))
                        .foregroundStyle(UITheme.primaryText)
                        .frame(width: 36, height: 36)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("common.clear"))
            }
        }
    }

    // MARK: - Actions

    private func send() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isComposerPresented = false

        manager.startMatching(text: input, context: context)
        text = ""
        currentPage = .glimmer

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            isMatchingPresented = true
        }
    }

    private func closeCurrentGlimmer() {
        resetToVerse()
    }

    private func recoverToVerseAfterError() {
        resetToVerse()
        shouldRecoverToVerseAfterError = false
    }

    private func resetToVerse() {
        manager.reset()
        isMatchingPresented = false
        currentPage = .glimmer
        isComposerPresented = false
    }

    private func presentComposer() {
        isComposerPresented = true
    }

    private func dismissComposer() {
        isComposerPresented = false
    }

    private func clearComposer() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()

        withAnimation(.easeInOut(duration: 0.24)) {
            text = ""
        }
    }
}

// MARK: - Hero Verse

private struct HeroVerse: View {
    var body: some View {
        Text("starsea.hero.verse")
            .font(.title3)
            .fontDesign(.serif)
            .tracking(2.0)
            .multilineTextAlignment(.center)
            .foregroundStyle(UITheme.primaryText.opacity(0.65))
            .lineSpacing(12)
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Floating Write Button

private struct FloatingWriteButton: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "pencil")
                .font(.title3.weight(.medium))
                .foregroundStyle(.black)
                .frame(width: 56, height: 56)
                .contentShape(Circle())
                .background(UITheme.accent, in: Circle())
                .overlay(
                    Circle()
                        .strokeBorder(.white.opacity(0.28), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("starsea.prompt.glimmerWithin"))
    }
}

// MARK: - Draft Glimmer

private struct DraftGlimmerCard: View {
    let content: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            GlimmerCardView(content: content)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("starsea.prompt.glimmerWithin"))
    }
}

// MARK: - Matching View

private struct MatchingView: View {
    let manager: MatchingManager
    @Binding var currentPage: CardID?
    @Binding var chatRoute: EchoChatRoute?
    let onClose: () -> Void

    private var echoes: [Echo] {
        (manager.currentGlimmer?.echoes ?? [])
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var hasEchoes: Bool {
        !echoes.isEmpty
    }

    private var selectedEcho: Echo? {
        guard case let .echo(echoId) = currentPage else { return nil }
        return echoes.first(where: { $0.id == echoId })
    }

    private var activeEchoChatRoute: EchoChatRoute? {
        guard let selectedEcho else { return nil }
        return EchoChatRoute(
            echo: selectedEcho,
            glimmerContent: manager.currentGlimmer?.content ?? manager.text
        )
    }

    private var shouldShowChatButton: Bool {
        activeEchoChatRoute != nil
    }

    private var shouldShowListeningChip: Bool {
        manager.isMatching && !hasEchoes
    }

    var body: some View {
        ZStack {
            StarryBackgroundView()
            matchingContent
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            matchingToolbarContent
        }
    }

    private var matchingContent: some View {
        VStack(spacing: 16) {
            CardPagerView(
                echoes: echoes,
                currentPage: $currentPage,
                autoSwitchToFirstEcho: true
            ) {
                GlimmerCardView(content: manager.text)
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.vertical)

            if shouldShowListeningChip {
                VStack(spacing: 16) {
                    MatchingWaveIcon(ringSize: 12, containerSize: 24)

                    Text("matching.status.listening")
                        .font(.subheadline)
                        .tracking(1.5)
                        .foregroundStyle(UITheme.secondaryText)
                }
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .padding(.bottom, 60)
            }
        }
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
    }

    @ToolbarContentBuilder
    private var matchingToolbarContent: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            closeButton
        }

        if hasEchoes {
            ToolbarItem(placement: .bottomBar) {
                if shouldShowChatButton {
                    chatButton
                }
            }

            ToolbarItem(placement: .status) {
                CardPagerIndicatorView(echoes: echoes, currentPage: $currentPage, isMatching: manager.isMatching)
            }
        }
    }

    private var closeButton: some View {
        Button(role: .cancel, action: onClose) {
            Image(systemName: "chevron.left")
                .font(.body.weight(.medium))
                .foregroundStyle(UITheme.secondaryText)
                .padding(8)
                .contentShape(.circle)
        }
    }

    private var chatButton: some View {
        Button("resonance.chat.newConversation", systemImage: "message") {
            openChat()
        }
    }

    private func openChat() {
        guard let route = activeEchoChatRoute else { return }
        chatRoute = route
    }
}

// MARK: - Full Screen Composer

private struct StarSeaComposerCover: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var text: String
    let onDismiss: () -> Void
    let onSend: () -> Void
    @FocusState private var isEditorFocused: Bool

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var placeholderText: String {
        String(localized: "starsea.prompt.glimmerWithin")
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                StarryBackgroundView()
                    .ignoresSafeArea()

                editor
                    .padding(.horizontal, 24)
                    .padding(.top, 24)
                    .padding(.bottom, 18)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    leadingButton
                }

                ToolbarItem(placement: .topBarTrailing) {
                    sendButton
                }
            }
            .toolbar(.hidden, for: .tabBar)
        }
        .presentationBackground(.clear)
        .onAppear {
            Task { @MainActor in
                await Task.yield()
                isEditorFocused = true
            }
        }
    }

    private var editor: some View {
        ZStack(alignment: .topLeading) {
            if text.isEmpty {
                GlimmerCardText(placeholderText, foregroundStyle: UITheme.primaryText.opacity(0.42))
                    .padding(.top, 8)
                    .padding(.horizontal, 5)
                    .transition(.opacity)
            }

            TextEditor(text: $text)
                .focused($isEditorFocused)
                .font(.body)
                .fontDesign(.serif)
                .lineSpacing(8)
                .tracking(0.5)
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)
                .scrollContentBackground(.hidden)
                .scrollIndicators(.hidden)
                .contentMargins(0, for: .scrollContent)
                .background(.clear)
                .submitLabel(.send)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
                .accessibilityLabel(Text("starsea.prompt.glimmerWithin"))
        }
    }

    private var leadingButton: some View {
        Button(action: onDismiss) {
            Image(systemName: "chevron.down")
                .font(.body.weight(.medium))
                .foregroundStyle(UITheme.primaryText)
                .frame(width: 36, height: 36)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("common.cancel"))
    }

    private var sendButton: some View {
        Button(action: onSend) {
            Image(systemName: "arrow.up")
                .font(.body.weight(.semibold))
                .foregroundStyle(UITheme.primaryActionForeground(for: colorScheme))
                .frame(width: 36, height: 36)
                .background(UITheme.primaryActionBackground(for: colorScheme), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
        .opacity(canSend ? 1 : 0.45)
        .accessibilityLabel(Text("common.submit"))
    }
}

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
    @State private var isComposerActive = false
    @FocusState private var isComposerFocused: Bool
    @Binding var composeRequestID: Int

    init(composeRequestID: Binding<Int> = .constant(0)) {
        _composeRequestID = composeRequestID
    }

    var body: some View {
        NavigationStack {
            mainContent
                .navigationBarTitleDisplayMode(.inline)
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
                activateComposer()
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
                .onTapGesture {
                    isComposerFocused = false
                    if text.isEmpty {
                        isComposerActive = false
                    }
                }

            VStack(spacing: 0) {
                Spacer()

                ZStack {
                    if isComposerActive || !text.isEmpty {
                        CentralGlimmerComposer(
                            text: $text,
                            isFocused: $isComposerFocused,
                            onSend: send
                        )
                        .padding(.horizontal, 24)
                        .transition(.opacity.combined(with: .scale(scale: 0.98)))
                    } else {
                        HeroVerse()
                            .padding(.horizontal, 32)
                            .transition(.opacity.combined(with: .scale(scale: 1.02)))
                    }
                }
                .frame(maxWidth: .infinity)

                Spacer()

                if !isComposerActive && text.isEmpty {
                    BottomGlimmerPrompt {
                        activateComposer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 72)
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: 0.28), value: isComposerActive)
            .animation(.easeInOut(duration: 0.28), value: isComposerFocused)
            .animation(.easeInOut(duration: 0.22), value: text.isEmpty)
        }
    }

    // MARK: - Actions

    private func send() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        isComposerFocused = false
        isComposerActive = false

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
        isComposerFocused = false
        isComposerActive = false
    }

    private func activateComposer() {
        withAnimation(.easeInOut(duration: 0.28)) {
            isComposerActive = true
        }

        Task { @MainActor in
            await Task.yield()
            isComposerFocused = true
        }
    }
}

// MARK: - Hero Verse

private struct HeroVerse: View {
    var body: some View {
        Text("starsea.hero.verse")
            .font(.title2)
            .fontDesign(.serif)
            .tracking(1.2)
            .multilineTextAlignment(.center)
            .foregroundStyle(UITheme.primaryText.opacity(0.72))
            .lineSpacing(8)
            .accessibilityAddTraits(.isStaticText)
    }
}

// MARK: - Bottom Prompt

private struct BottomGlimmerPrompt: View {
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text("starsea.prompt.glimmerWithin")

                Image(systemName: "arrow.right")
                    .font(.callout.weight(.medium))
            }
            .font(.title3)
            .fontDesign(.serif)
            .foregroundStyle(UITheme.primaryText.opacity(0.42))
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
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

// MARK: - Central Composer

private struct CentralGlimmerComposer: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let onSend: () -> Void

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                HStack(spacing: 8) {
                    Text("starsea.prompt.glimmerWithin")

                    Image(systemName: "arrow.right")
                        .font(.callout.weight(.medium))
                }
                .font(.title3)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText.opacity(0.42))
                .allowsHitTesting(false)
                .transition(.opacity)
            }

            TextField("", text: $text)
                .focused(isFocused)
                .font(.title3)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)
                .tint(UITheme.primaryText)
                .submitLabel(.send)
                .textFieldStyle(.plain)
                .onSubmit {
                    if canSend {
                        onSend()
                    }
                }
                .accessibilityLabel(Text("starsea.prompt.glimmerWithin"))
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 18)
        .background {
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color.white.opacity(isFocused.wrappedValue ? 0.035 : 0))
                .shadow(
                    color: .white.opacity(isFocused.wrappedValue ? 0.035 : 0),
                    radius: 30,
                    x: 0,
                    y: 0
                )
            }
        .frame(maxWidth: 520, alignment: .leading)
        .animation(.easeInOut(duration: 0.22), value: isFocused.wrappedValue)
        .animation(.easeInOut(duration: 0.18), value: text.isEmpty)
    }
}

import Supabase
import SwiftData
import SwiftUI

struct StarSeaView: View {
    private enum StarSeaStage: Equatable {
        case verse
        case matching
    }

    @Environment(\.modelContext) private var context
    @State private var text = ""
    @State private var isPresented = false
    @State private var sidebarNavigation = SidebarNavigationState()
    @State private var stage: StarSeaStage = .verse
    @State private var manager = MatchingManager.shared
    @State private var showError = false
    @State private var showPaywall = false
    @State private var shouldRecoverToVerseAfterError = false
    @State private var currentPage: CardID? = .glimmer
    @State private var isShowingProfile = false
    @State private var chatRoute: EchoChatRoute?

    var body: some View {
        SidebarContainer(
            sidebarNavigation: $sidebarNavigation,
            isSidebarEnabled: isSidebarEnabled,
            onOpenGlimmerComposer: openGlimmerComposerFromSidebar
        ) {
            NavigationStack {
                mainContent
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    sidebarNavigation.isSidebarPresented.toggle()
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                            }
                        }
                        profileToolbarItem
                        matchingToolbarContent
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(isPresented: $isShowingProfile) {
                        ProfileView(onOpenGlimmerComposer: openGlimmerComposerFromProfile)
                    }
                    .navigationDestination(item: $sidebarNavigation.activeSession) { session in
                        ChatView(
                            sessionId: session.id,
                            soulerId: session.soulerId,
                            soulerName: session.soulerName,
                            focusComposerOnAppear: false
                        )
                    }
                    .navigationDestination(item: $sidebarNavigation.activeDraftChat) { draftTarget in
                        ChatView(
                            sessionId: nil,
                            soulerId: draftTarget.soulerId,
                            soulerName: draftTarget.soulerName,
                            focusComposerOnAppear: false
                        )
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
                    }
            }
        }
        .fullScreenCover(isPresented: $isPresented) {
            ComposeView(text: $text, onSend: send)
                .presentationBackground(.clear)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .onChange(of: manager.errorMessage) { _, newValue in
            if stage == .matching, newValue != nil {
                shouldRecoverToVerseAfterError = true
            }
            showError = newValue != nil
        }
        .onChange(of: showError) { _, isShowing in
            if !isShowing, shouldRecoverToVerseAfterError {
                recoverToVerseAfterError()
            }
        }
        .onChange(of: isShowingProfile) { _, isShowing in
            if isShowing {
                withAnimation(.easeInOut(duration: 0.2)) {
                    sidebarNavigation.isSidebarPresented = false
                }
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

            if stage == .matching {
                matchingContent
            } else {
                VStack {
                    Spacer()

                    VerseView(textKey: "starsea.hero.verse")

                    Spacer()

                    magicButtonView
                }
                .opacity(isPresented ? 0 : 1)
                .animation(.easeInOut(duration: 0.2), value: isPresented)
            }
        }
    }

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
        stage == .matching && activeEchoChatRoute != nil
    }

    private var shouldShowMatchingToolbar: Bool {
        stage == .matching
    }

    private var isSidebarEnabled: Bool {
        sidebarNavigation.isStarSeaDestination && chatRoute == nil && !isShowingProfile
    }

    private var shouldShowListeningChip: Bool {
        shouldShowMatchingToolbar && manager.isMatching && !hasEchoes
    }

    @ToolbarContentBuilder
    private var profileToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            Button {
                isShowingProfile = true
            } label: {
                Image(systemName: "person.crop.circle")
            }
        }
    }

    @ToolbarContentBuilder
    private var matchingToolbarContent: some ToolbarContent {
        if shouldShowMatchingToolbar {
            if hasEchoes {
                ToolbarItem(placement: .bottomBar) {
                    closeButton
                }

                ToolbarSpacer(placement: .bottomBar)

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
    }

    private var magicButtonView: some View {
        Group {
            if text.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")

                    Text("starsea.prompt.glimmerWithin")
                        .foregroundStyle(UITheme.primaryText)
                        .font(.body)
                        .fontDesign(.serif)
                }
                .padding()
                .glassEffect(in: .capsule)
            } else {
                draftPreviewField
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 20))
                    .contentShape(.rect)
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            isPresented = true
                        }
                    )
                    .padding(.horizontal)
            }
        }
        .onTapGesture {
            if manager.isMatching {
                stage = .matching
            } else {
                isPresented = true
            }
        }
    }

    private var draftPreviewField: some View {
        TextField("", text: .constant(text), axis: .vertical)
            .font(.body)
            .fontDesign(.serif)
            .lineLimit(1 ... 5)
            .foregroundStyle(UITheme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textFieldStyle(.plain)
    }

    // MARK: - Actions

    private func send() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }

        UIImpactFeedbackGenerator(style: .medium).impactOccurred()

        manager.startMatching(text: input, context: context)
        text = ""
        currentPage = .glimmer

        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            stage = .matching
        }
    }

    private func closeCurrentGlimmer() {
        resetToVerse()
    }

    private func recoverToVerseAfterError() {
        resetToVerse()
        shouldRecoverToVerseAfterError = false
    }

    private func openGlimmerComposerFromSidebar() {
        isPresented = true
    }

    private func openGlimmerComposerFromProfile() {
        isShowingProfile = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            isPresented = true
        }
    }

    private func resetToVerse() {
        manager.reset()
        stage = .verse
        currentPage = .glimmer
    }
}

extension StarSeaView {
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

    private var closeButton: some View {
        Button(role: .cancel, action: closeCurrentGlimmer) {
            Image(systemName: "chevron.down")
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

// MARK: - Verse View

private struct VerseView: View {
    let textKey: LocalizedStringKey

    var body: some View {
        VStack {
            Spacer()

            Text(textKey)
                .padding(20)
                .font(.title2)
                .fontDesign(.serif)
                .multilineTextAlignment(.center)
                .lineSpacing(14)
                .tracking(3)
                .foregroundStyle(UITheme.primaryText.opacity(0.85))
                .shadow(color: .white.opacity(0.12), radius: 16)
                .shadow(color: .white.opacity(0.06), radius: 32)

            Spacer()
        }
    }
}

// MARK: - Compose View

private struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("starsea.prompt.glimmerWithin", text: $text, axis: .vertical)
                    .focused($isFocused)
                    .font(.body)
                    .fontDesign(.serif)
                    .lineSpacing(6)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
                    .contentShape(.rect)
                    .onTapGesture(perform: dismissKeyboard)
            }
            .background(.clear)
            .navigationTitle("glimmer.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(role: .close) {
                        dismissKeyboard()
                        dismiss()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .confirm) {
                        dismissKeyboard()
                        onSend()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .background(.black.opacity(0.4))
        .onAppear {
            isFocused = true
        }
    }

    private func dismissKeyboard() {
        isFocused = false
    }
}

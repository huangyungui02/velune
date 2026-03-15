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
    @State private var shouldRecoverToVerseAfterError = false
    @State private var currentPage: CardID? = .glimmer
    @State private var isShowingProfile = false
    @State private var chatRoute: EchoChatRoute?

    var body: some View {
        SidebarContainer(
            sidebarNavigation: $sidebarNavigation,
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
                            .accessibilityLabel(Text("starsea.action.resonances"))
                        }
                        profileToolbarItem
                        matchingToolbarContent
                    }
                    .navigationBarTitleDisplayMode(.inline)
                    .navigationDestination(isPresented: $isShowingProfile) {
                        ProfileView()
                    }
                    .navigationDestination(item: $chatRoute) { route in
                        ChatView(
                            sessionId: route.sessionId,
                            soulerId: route.soulerId,
                            soulerName: route.soulerName,
                            focusComposerOnAppear: true
                        )
                    }
            }
        }
        .fullScreenCover(isPresented: $isPresented) {
            ComposeView(text: $text, onSend: send)
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

    @ViewBuilder
    private var mainContent: some View {
        if let session = sidebarNavigation.activeSession {
            ChatView(
                sessionId: session.id,
                soulerId: session.soulerId,
                soulerName: session.soulerName,
                onSelectSession: { selectedSession in
                    sidebarNavigation.activeSession = selectedSession
                }
            )
        } else {
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
                }
            }
        }
    }

    private var isStarSeaDestination: Bool {
        sidebarNavigation.isStarSeaDestination
    }

    private var echoes: [Echo] {
        (manager.currentGlimmer?.echoes ?? [])
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var hasEchoes: Bool {
        !echoes.isEmpty
    }

    private var shouldShowCloseButton: Bool {
        stage == .matching && !manager.isMatching && manager.currentGlimmer?.status == "complete"
    }

    private var shouldShowWaveButton: Bool {
        stage == .matching && manager.isMatching && hasEchoes
    }

    private var selectedEcho: Echo? {
        guard case let .echo(echoId) = currentPage else { return nil }
        return echoes.first(where: { $0.id == echoId })
    }

    private var activeEchoChatRoute: EchoChatRoute? {
        guard let selectedEcho, let sessionId = selectedEcho.sessionId else { return nil }
        return EchoChatRoute(sessionId: sessionId, echo: selectedEcho)
    }

    private var shouldShowChatButton: Bool {
        stage == .matching && activeEchoChatRoute != nil
    }

    private var shouldShowMatchingToolbar: Bool {
        isStarSeaDestination && stage == .matching
    }

    private var shouldShowListeningChip: Bool {
        shouldShowMatchingToolbar && manager.isMatching && !hasEchoes
    }

    @ToolbarContentBuilder
    private var profileToolbarItem: some ToolbarContent {
        if isStarSeaDestination {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    isShowingProfile = true
                } label: {
                    Image(systemName: "house.fill")
                }
            }
        }
    }

    @ToolbarContentBuilder
    private var matchingToolbarContent: some ToolbarContent {
        if shouldShowMatchingToolbar {
            if shouldShowListeningChip {
                ToolbarItem(placement: .status) {
                    listeningToolbarChip
                }
            } else if hasEchoes {
                ToolbarItem(placement: .bottomBar) {
                    if shouldShowWaveButton {
                        MatchingWaveIcon()
                            .frame(width: 24, height: 24)
                    } else if shouldShowCloseButton {
                        closeButton
                    }
                }

                ToolbarSpacer(placement: .bottomBar)

                ToolbarItem(placement: .bottomBar) {
                    if shouldShowChatButton {
                        chatButton
                    }
                }

                ToolbarItem(placement: .status) {
                    CardPagerIndicatorView(echoes: echoes, currentPage: $currentPage)
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
        manager.startMatching(text: input, context: context)
        text = ""
        currentPage = .glimmer
        stage = .matching
    }

    private func closeCurrentGlimmer() {
        guard shouldShowCloseButton else { return }
        resetToVerse()
    }

    private func recoverToVerseAfterError() {
        resetToVerse()
        shouldRecoverToVerseAfterError = false
    }

    private func openGlimmerComposerFromSidebar() {
        sidebarNavigation.activeSession = nil
        isPresented = true
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
        }
    }

    private var listeningToolbarChip: some View {
        HStack(spacing: 12) {
            MatchingWaveIcon()

            Text("matching.status.listening")
                .font(.footnote.weight(.medium))
                .foregroundStyle(UITheme.primaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var closeButton: some View {
        Button(action: closeCurrentGlimmer) {
            Image(systemName: "xmark")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(UITheme.primaryText)
        }
        .buttonStyle(.plain)
    }

    private var chatButton: some View {
        Button("resonance.chat.newConversation", systemImage: "message") {
            openChat()
        }
        .labelStyle(.iconOnly)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(UITheme.primaryText)
        .contentShape(.rect)
        .accessibilityLabel(Text("resonance.chat.newConversation"))
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
                .font(.title2)
                .fontDesign(.serif)
                .multilineTextAlignment(.center)
                .lineSpacing(14)
                .tracking(2)
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
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(white: 0.06),
                        Color(white: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("glimmer.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(UITheme.secondaryText)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        onSend()
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(UITheme.primaryText)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 1)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    StarSeaView()
}

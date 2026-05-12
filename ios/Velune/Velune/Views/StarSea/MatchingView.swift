import SwiftUI

struct MatchingView: View {
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

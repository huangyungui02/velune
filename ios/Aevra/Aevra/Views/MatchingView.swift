import SwiftUI

struct MatchingView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var manager = MatchingManager.shared
    @State private var showError = false
    @State private var currentPage: CardID? = .glimmer
    @State private var chatDestination: EchoChatDestination?

    private var echoes: [Echo] {
        (manager.currentGlimmer?.echoes ?? [])
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var hasEchoes: Bool {
        !echoes.isEmpty
    }

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 16) {
                cardPagerView
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.vertical)

                indicatorView
            }
        }
        .onChange(of: manager.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert("matching.error.title", isPresented: $showError) {
            Button("common.ok", role: .cancel) {
                manager.reset()
                dismiss()
            }
        } message: {
            if let errorMessage = manager.errorMessage {
                Text(errorMessage)
            } else {
                Text("matching.error.unknown")
            }
        }
        .navigationDestination(item: $chatDestination) { destination in
            destination.makeChatView()
        }
    }

    private var cardPagerView: some View {
        CardPagerView(
            echoes: echoes,
            currentPage: $currentPage,
            autoSwitchToFirstEcho: true
        ) { maxCardHeight in
            GlimmerCardView(content: manager.text, maxCardHeight: maxCardHeight)
        } echoCard: { echo, maxCardHeight in
            EchoCardView(
                echo: echo,
                glimmerContent: manager.text,
                maxCardHeight: maxCardHeight,
                onOpenChat: { destination in
                    chatDestination = destination
                }
            )
        }
    }

    private var indicatorView: some View {
        HStack(spacing: 8) {
            CardPagerIndicatorView(echoes: echoes, currentPage: $currentPage)

            if manager.isMatching {
                HStack(spacing: 12) {
                    MatchingWaveIcon()

                    if !hasEchoes {
                        Text("matching.status.listening")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(UITheme.secondaryText)
                            .tracking(2)
                    }
                }
                .padding()
                .glassEffect()
            }
        }
    }
}

#Preview {
    ZStack {
        BackgroundView()
        EchoCardView(echo: Echo.sampleData[0], glimmerContent: Glimmer.sampleData[0].content)
    }
}

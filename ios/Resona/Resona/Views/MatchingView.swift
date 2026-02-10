import Supabase
import SwiftData
import SwiftUI

struct MatchingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var manager = MatchingManager.shared
    @State private var showError = false
    @State private var currentPage: CardID? = .soulFragment
    
    private var echoes: [Echo] {
        manager.currentInspiration?.echoes ?? []
    }
    
    private var hasEchoes: Bool {
        !echoes.isEmpty
    }
    
    var body: some View {
        ZStack {
            BackgroundView()
            
            VStack {
                cardPagerView

                Spacer()
                
                indicatorView
            }
        }
        .onChange(of: manager.errorMessage) { _, newValue in
            showError = newValue != nil
        }
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) {
                manager.reset()
                dismiss()
            }
        } message: {
            Text(manager.errorMessage ?? "Unknown error")
        }
    }
    
    private var cardPagerView: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                // Soul Fragment card
                soulFragmentCard
                    .containerRelativeFrame(.horizontal)
                    .id(CardID.soulFragment)
                
                // Echo cards
                ForEach(echoes) { echo in
                    PremiumEchoCardView(echo: echo)
                        .containerRelativeFrame(.horizontal)
                        .id(CardID.echo(echo.id))
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollPosition(id: $currentPage)
        .scrollIndicators(.hidden)
        .onChange(of: hasEchoes) { _, newValue in
            // Switch to first echo when echoes appear
            if newValue, case .soulFragment = currentPage {
                if let firstEcho = echoes.first {
                    withAnimation {
                        currentPage = .echo(firstEcho.id)
                    }
                }
            }
        }
    }
    
    private var soulFragmentCard: some View {
        PremiumCardView(iconName: "sparkles", title: "Soul Fragment") {
            Text(manager.text)
                .lineSpacing(8)
                .foregroundStyle(.white)
        }
    }
    
    private var indicatorView: some View {
        HStack(spacing: 8) {
            if hasEchoes {
                HStack(spacing: 8) {
                    Button {
                        withAnimation {
                            currentPage = .soulFragment
                        }
                    } label: {
                        Image(systemName: "sparkle")
                            .font(.caption2)
                            .foregroundStyle(currentPage == .soulFragment ? .white : .white.opacity(0.3))
                            .frame(width: 10, height: 10)
                            .scaleEffect(currentPage == .soulFragment ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                    .buttonStyle(.plain)
                    
                    ForEach(echoes) { echo in
                        Circle()
                            .fill(currentPage == .echo(echo.id) ? .white : .white.opacity(0.3))
                            .frame(width: 8, height: 8)
                            .scaleEffect(currentPage == .echo(echo.id) ? 1.2 : 1.0)
                            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
                    }
                }
                .padding()
                .glassEffect()
            }
            
            if manager.isMatching {
                HStack(spacing: 12) {
                    MatchingWaveIcon()
                    
                    if !hasEchoes {
                        Text("Finding resonance…")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                            .tracking(2)
                    }
                }
                .padding()
                .glassEffect()
            }
        }
    }
}

// MARK: - Card Identifier

private enum CardID: Hashable {
    case soulFragment
    case echo(UUID)
}

// MARK: - Subviews

private struct PremiumEchoCardView: View {
    let echo: Echo
    
    var body: some View {
        PremiumCardView(iconName: "circle.circle", title: "Echo") {
            VStack(spacing: 20) {
                Text(echo.content)
                    .lineSpacing(8)
                    .foregroundStyle(.white)
                    
                Divider()
                    .background(.white.opacity(0.3))
                    
                NavigationLink {
                    SoulerView(soulerId: echo.soulerId)
                } label: {
                    HStack(spacing: 8) {
                        Spacer()

                        Text(echo.soulerName)
                            .font(.headline)
                            .foregroundStyle(.white)

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

#Preview {
    ZStack {
        BackgroundView()
        PremiumEchoCardView(echo: Echo.sampleData[0])
    }
}

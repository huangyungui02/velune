import Supabase
import SwiftData
import SwiftUI

struct MatchingView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    
    @State private var manager = MatchingManager.shared
    @State private var showError = false
    @State private var currentPage: CardID? = .glimmer
    
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
                glimmerCard
                    .containerRelativeFrame(.horizontal)
                    .id(CardID.glimmer)
                
                // Echo cards
                ForEach(echoes) { echo in
                    EchoCardView(echo: echo)
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
            if newValue, case .glimmer = currentPage {
                if let firstEcho = echoes.first {
                    withAnimation {
                        currentPage = .echo(firstEcho.id)
                    }
                }
            }
        }
    }
    
    private var glimmerCard: some View {
        GlimmerCardView(content: manager.text)
    }
    
    private var indicatorView: some View {
        HStack(spacing: 8) {
            EchoPagerIndicatorView(echoes: echoes, currentPage: $currentPage)
            
            if manager.isMatching {
                HStack(spacing: 12) {
                    MatchingWaveIcon()
                    
                    if !hasEchoes {
                        Text("Listening for echoes")
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
        EchoCardView(echo: Echo.sampleData[0])
    }
}

import SwiftUI

struct StarSeaSettlementSheet: View {
    let text: String
    let isGenerating: Bool
    let isReady: Bool
    let onExit: () -> Void

    var body: some View {
        NavigationStack {
            ZStack {
                StarryBackgroundView()
                    .ignoresSafeArea()

                content
            }
            .navigationTitle("starsea.settlement.glimmerTitle")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if isReady {
                        Button(action: onExit) {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.body.weight(.medium))
                        }
                        .accessibilityLabel(Text("starsea.settlement.exit"))
                    }
                }
            }
        }
    }

    private var content: some View {
        ScrollView {
            GlimmerCardView(
                content: text,
                isGenerating: isGenerating
            )
            .padding(.horizontal, 18)
            .padding(.top, 22)
            .padding(.bottom, 28)
        }
    }
}

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
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 18) {
                    if text.isEmpty && isGenerating {
                        HStack(spacing: 10) {
                            ProgressView()
                                .tint(UITheme.primaryText)
                            Text("starsea.settlement.generating")
                                .font(.subheadline)
                                .foregroundStyle(UITheme.secondaryText)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(text)
                            .font(.body)
                            .lineSpacing(7)
                            .foregroundStyle(UITheme.primaryText)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .animation(.easeOut(duration: 0.16), value: text)
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.white.opacity(0.055), in: .rect(cornerRadius: 24))
                .glassEffect(in: .rect(cornerRadius: 24))
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(.white.opacity(0.10), lineWidth: 0.5)
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)
            .padding(.bottom, 28)
        }
    }
}

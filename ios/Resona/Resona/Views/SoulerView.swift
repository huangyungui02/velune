import MarkdownUI
import SwiftUI

struct SoulerView: View {
    let soulerId: UUID
    @State private var souler: Souler?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            BackgroundView()

            contentView
        }
        .task(id: soulerId) {
            await loadSouler()
        }
    }

    private var contentView: some View {
        Group {
            if let souler = souler {
                soulerDetailView(souler)
            } else if let errorMessage = errorMessage {
                VStack(spacing: 12) {
                    Text("Failed to load")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)

                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)

                    Button("Retry") {
                        Task {
                            await loadSouler()
                        }
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
            } else {
                ProgressView("Loading…")
                    .tint(.white)
            }
        }
        .animation(.easeInOut, value: souler != nil)
    }

    private func soulerDetailView(_ souler: Souler) -> some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(souler.name)
                    .font(.title)
                    .fontWeight(.bold)

                if let alias = souler.alias {
                    Text(alias)
                        .font(.headline)
                        .foregroundStyle(.secondary)
                }

                CardView {
                    Markdown(souler.bio)
                }.padding()
            }
            .padding(.vertical)
        }
    }

    private func loadSouler() async {
        if isLoading { return }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
        }

        do {
            let result = try await Souler.get(soulerId)
            await MainActor.run {
                souler = result
            }
        } catch {
            await MainActor.run {
                errorMessage = error.localizedDescription
            }
        }

        await MainActor.run {
            isLoading = false
        }
    }
}

#Preview {
    NavigationStack {
        SoulerView(soulerId: Souler.sampleData[0].id)
    }
}

import SwiftData
import SwiftUI

struct GlimmerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingDeleteAlert = false
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var glimmer: Glimmer
    @State private var currentPage: CardID? = .glimmer

    init(glimmer: Glimmer) {
        self.glimmer = glimmer
    }

    private var echoes: [Echo] {
        glimmer.echoes.sorted { $0.createdAt < $1.createdAt }
    }

    private var hasEchoes: Bool { !echoes.isEmpty }

    var body: some View {
        ZStack {
            BackgroundView()

            VStack {
                cardPagerView

                if isLoading {
                    ProgressView()
                }

                Spacer()

                indicatorView
            }
        }
        .navigationTitle("Glimmer")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(isDeleting)
            }
        }
        .alert("Delete", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task {
                    let success = await deleteGlimmer()
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("Are you sure you want to delete this? This action can’t be undone.")
        }
        .overlay {
            if isDeleting {
                ProgressView("Deleting…")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
        .task {
            await refreshGlimmer()
        }
    }

    func deleteGlimmer() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await Glimmer.delete(glimmer.id)
            context.delete(glimmer)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshGlimmer() async {
        if glimmer.status == "complete" {
            if !glimmer.echoes.isEmpty { return }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let newGlimmer = try await Glimmer.get(glimmer.id)
            let echoes = try await Echo.getAll(newGlimmer.id)
            newGlimmer.echoes = echoes
            glimmer.update(from: newGlimmer)
        } catch {
            print("Failed to refresh glimmer \(glimmer.id): \(error)")
            return
        }
    }

    @ViewBuilder
    private var cardPagerView: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                glimmerCard
                    .containerRelativeFrame(.horizontal)
                    .id(CardID.glimmer)

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
    }

    private var glimmerCard: some View {
        GlimmerCardView(content: glimmer.content, createdAt: glimmer.createdAt)
    }

    private var indicatorView: some View {
        HStack(spacing: 8) {
            EchoPagerIndicatorView(echoes: echoes, currentPage: $currentPage)
        }
    }
}

#Preview {
    let glimmer = Glimmer.sampleData[0]
    NavigationStack {
        GlimmerView(glimmer: glimmer)
            .sampleDataContainer()
    }
}

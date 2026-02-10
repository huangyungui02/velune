import SwiftData
import SwiftUI

struct InspirationDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingDeleteAlert = false
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var inspiration: Inspiration
    @State private var currentPage: CardID? = .soulFragment

    init(inspiration: Inspiration) {
        self.inspiration = inspiration
    }

    private var echoes: [Echo] {
        inspiration.echoes.sorted { $0.createdAt < $1.createdAt }
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
        .navigationTitle("Soul Fragment")
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
                    let success = await deleteInspiration()
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
            await refreshInspiration()
        }
    }

    func deleteInspiration() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await Inspiration.delete(inspiration.id)
            context.delete(inspiration)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshInspiration() async {
        if inspiration.status == "complete" {
            if !inspiration.echoes.isEmpty { return }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let newInspiration = try await Inspiration.get(inspiration.id)
            let echoes = try await Echo.getAll(newInspiration.id)
            newInspiration.echoes = echoes
            inspiration.update(from: newInspiration)
        } catch {
            print("Failed to refresh inspiration \(inspiration.id): \(error)")
            return
        }
    }

    @ViewBuilder
    private var cardPagerView: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                soulFragmentCard
                    .containerRelativeFrame(.horizontal)
                    .id(CardID.soulFragment)

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

    private var soulFragmentCard: some View {
        SoulFragmentCardView(content: inspiration.content, createdAt: inspiration.createdAt)
    }

    private var indicatorView: some View {
        HStack(spacing: 8) {
            EchoPagerIndicatorView(echoes: echoes, currentPage: $currentPage)
        }
    }
}

#Preview {
    let inspiration = Inspiration.sampleData[0]
    NavigationStack {
        InspirationDetailView(inspiration: inspiration)
            .sampleDataContainer()
    }
}

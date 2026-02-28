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

    var body: some View {
        ZStack {
            BackgroundView()

            VStack(spacing: 16) {
                cardPagerView
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.vertical)

                if isLoading {
                    ProgressView()
                } else {
                    indicatorView
                }
            }
        }
        .navigationTitle(L10n.string("glimmer.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label(L10n.string("glimmer.action.delete"), systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(isDeleting)
            }
        }
        .alert(L10n.string("glimmer.delete.title"), isPresented: $showingDeleteAlert) {
            Button(L10n.string("common.cancel"), role: .cancel) {}
            Button(L10n.string("glimmer.action.delete"), role: .destructive) {
                Task {
                    let success = await deleteGlimmer()
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text(L10n.string("glimmer.delete.message"))
        }
        .overlay {
            if isDeleting {
                ProgressView(L10n.string("glimmer.delete.progress"))
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

    private var cardPagerView: some View {
        GeometryReader { proxy in
            let maxCardHeight = proxy.size.height
            let cardHeightLimit = maxCardHeight > 0 ? maxCardHeight : nil

            ScrollView(.horizontal) {
                LazyHStack(spacing: 0) {
                    glimmerCard(maxCardHeight: cardHeightLimit)
                        .containerRelativeFrame(.horizontal)
                        .id(CardID.glimmer)

                    ForEach(echoes) { echo in
                        EchoCardView(
                            echo: echo,
                            glimmerContent: glimmer.content,
                            maxCardHeight: cardHeightLimit
                        )
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
    }

    private func glimmerCard(maxCardHeight: CGFloat?) -> some View {
        GlimmerCardView(
            content: glimmer.content,
            createdAt: glimmer.createdAt,
            maxCardHeight: maxCardHeight
        )
    }

    private var indicatorView: some View {
        EchoPagerIndicatorView(echoes: echoes, currentPage: $currentPage)
    }
}

#Preview {
    let glimmer = Glimmer.sampleData[0]
    NavigationStack {
        GlimmerView(glimmer: glimmer)
            .sampleDataContainer()
    }
}

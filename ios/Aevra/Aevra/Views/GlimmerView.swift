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
    @State private var chatRoute: EchoChatRoute?

    init(glimmer: Glimmer) {
        self.glimmer = glimmer
    }

    private var echoes: [Echo] {
        glimmer.echoes.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ZStack {
            BackgroundView()

            cardPagerView
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.vertical)
        }
        .navigationTitle("glimmer.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("glimmer.action.delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(isDeleting)
            }

            ToolbarItem(placement: .bottomBar) {
                if isLoading {
                    ProgressView()
                } else {
                    indicatorView
                }
            }
        }
        .alert("glimmer.delete.title", isPresented: $showingDeleteAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("glimmer.action.delete", role: .destructive) {
                Task {
                    let success = await deleteGlimmer()
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("glimmer.delete.message")
        }
        .overlay {
            if isDeleting {
                ProgressView("glimmer.delete.progress")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
        .task {
            await refreshGlimmer()
        }
        .navigationDestination(item: $chatRoute) { route in
            ChatView(
                soulerId: route.soulerId,
                soulerName: route.soulerName,
                initialSeedMessages: route.initialSeedMessages,
                initialDisplayMessages: route.initialDisplayMessages,
                initialReply: route.initialReply
            )
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
        CardPagerView(
            echoes: echoes,
            currentPage: $currentPage,
            autoSwitchToFirstEcho: false
        ) { maxCardHeight in
            GlimmerCardView(
                content: glimmer.content,
                createdAt: glimmer.createdAt,
                maxCardHeight: maxCardHeight
            )
        } echoCard: { echo, maxCardHeight in
            EchoCardView(
                echo: echo,
                glimmerContent: glimmer.content,
                maxCardHeight: maxCardHeight,
                onOpenChat: { route in
                    chatRoute = route
                }
            )
        }
    }

    private var indicatorView: some View {
        CardPagerIndicatorView(echoes: echoes, currentPage: $currentPage)
    }
}

#Preview {
    let glimmer = Glimmer.sampleData[0]
    NavigationStack {
        GlimmerView(glimmer: glimmer)
            .sampleDataContainer()
    }
}

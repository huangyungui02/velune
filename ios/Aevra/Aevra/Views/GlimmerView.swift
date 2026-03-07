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
                Spacer()
            }

            ToolbarItem(placement: .bottomBar) {
                if isLoading {
                    ProgressView()
                } else {
                    indicatorView
                }
            }

            ToolbarItem(placement: .bottomBar) {
                Spacer()
            }

            ToolbarItem(placement: .bottomBar) {
                if shouldShowChatButton {
                    chatButton
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
                sessionId: route.sessionId,
                soulerId: route.soulerId,
                soulerName: route.soulerName,
                focusComposerOnAppear: true
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
        ) {
            GlimmerCardView(
                content: glimmer.content,
                createdAt: glimmer.createdAt
            )
        } echoCard: { echo in
            EchoCardView(echo: echo)
        }
    }

    private var indicatorView: some View {
        CardPagerIndicatorView(echoes: echoes, currentPage: $currentPage)
    }

    private var selectedEcho: Echo? {
        guard case let .echo(echoId) = currentPage else { return nil }
        return echoes.first(where: { $0.id == echoId })
    }

    private var activeEchoChatRoute: EchoChatRoute? {
        guard let selectedEcho, let sessionId = selectedEcho.sessionId else { return nil }
        return EchoChatRoute(sessionId: sessionId, echo: selectedEcho)
    }

    private var shouldShowChatButton: Bool {
        activeEchoChatRoute != nil
    }

    private var chatButton: some View {
        Button {
            guard let route = activeEchoChatRoute else { return }
            chatRoute = route
        } label: {
            Image(systemName: "message")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(UITheme.primaryText)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    let glimmer = Glimmer.sampleData[0]
    NavigationStack {
        GlimmerView(glimmer: glimmer)
            .sampleDataContainer()
    }
}

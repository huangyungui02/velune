import OSLog
import SwiftData
import SwiftUI

struct StirringView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @State private var showingDeleteAlert = false
    @State private var isDeleting: Bool = false
    @State private var errorMessage: String? = nil
    @State private var isLoading: Bool = false
    @State private var stirring: Stirring
    @State private var currentPage: CardID? = .stirring
    @State private var chatRoute: EchoChatRoute?
    private let logger = AppLogger.storage

    init(stirring: Stirring) {
        self.stirring = stirring
    }

    private var echoes: [Echo] {
        stirring.echoes.sorted { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        ZStack {
            BackgroundView()

            cardPagerView
                .frame(maxHeight: .infinity, alignment: .top)
                .padding(.vertical)
        }
        .navigationTitle("stirring.title")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        Label("stirring.action.delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                }
                .disabled(isDeleting)
            }

            ToolbarSpacer(placement: .bottomBar)

            ToolbarItem(placement: .status) {
                if isLoading {
                    ProgressView()
                } else {
                    indicatorView
                }
            }

            ToolbarSpacer(placement: .bottomBar)

            ToolbarItem(placement: .bottomBar) {
                if shouldShowChatButton {
                    chatButton
                }
            }
        }
        .navigationDestination(item: $chatRoute) { route in
            ChatView(
                sessionId: route.sessionId,
                echoId: route.sessionId == nil ? route.echoId : nil,
                draftPrelude: route.draftPrelude,
                soulerId: route.soulerId,
                soulerName: route.soulerName,
                focusComposerOnAppear: true
            )
        }
        .alert("stirring.delete.title", isPresented: $showingDeleteAlert) {
            Button("common.cancel", role: .cancel) {}
            Button("stirring.action.delete", role: .destructive) {
                Task {
                    let success = await deleteStirring()
                    if success {
                        dismiss()
                    }
                }
            }
        } message: {
            Text("stirring.delete.message")
        }
        .alert("settings.error.title", isPresented: errorAlertBinding) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
        .overlay {
            if isDeleting {
                ProgressView("stirring.delete.progress")
                    .padding()
                    .background(.regularMaterial)
                    .cornerRadius(10)
            }
        }
        .task {
            await refreshStirring()
        }
    }

    func deleteStirring() async -> Bool {
        isDeleting = true
        defer { isDeleting = false }

        do {
            try await Stirring.delete(stirring.id)
            context.delete(stirring)
            try context.save()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func refreshStirring() async {
        if stirring.status != "pending", stirring.status != "processing" {
            if !stirring.echoes.isEmpty || stirring.status == "failed" { return }
        }

        isLoading = true
        defer { isLoading = false }

        do {
            let newStirring = try await Stirring.get(stirring.id)
            let remoteEchoes = try await Echo.getAll(newStirring.id)

            context.insert(newStirring)
            for echo in remoteEchoes {
                echo.stirring = newStirring
                context.insert(echo)
            }

            try? context.save()
        } catch {
            logger.error("refreshing stirring failed: stirringId=\(stirring.id.uuidString, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            return
        }
    }

    private var cardPagerView: some View {
        CardPagerView(
            echoes: echoes,
            currentPage: $currentPage,
            autoSwitchToFirstEcho: false
        ) {
            StirringCardView(
                content: stirring.content,
                createdAt: stirring.createdAt
            )
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
        guard let selectedEcho else { return nil }
        return EchoChatRoute(
            echo: selectedEcho,
            stirringContent: stirring.content
        )
    }

    private var shouldShowChatButton: Bool {
        activeEchoChatRoute != nil
    }

    private var chatButton: some View {
        Button("resonance.chat.newConversation", systemImage: "message") {
            openChat()
        }
        .labelStyle(.iconOnly)
        .font(.footnote.weight(.semibold))
        .foregroundStyle(UITheme.primaryText)
        .contentShape(.rect)
    }

    private func openChat() {
        guard let route = activeEchoChatRoute else { return }
        chatRoute = route
    }

    private var errorAlertBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }
}

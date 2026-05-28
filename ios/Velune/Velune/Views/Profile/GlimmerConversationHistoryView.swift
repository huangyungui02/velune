import SwiftUI

struct GlimmerConversationHistoryView: View {
    let glimmer: Glimmer

    @State private var messages: [GlimmerMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            StarryBackgroundView()

            if isLoading && messages.isEmpty {
                ProgressView("common.loading")
                    .tint(UITheme.primaryText)
            } else if messages.isEmpty {
                ContentUnavailableView(
                    "glimmerHistory.history.empty",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(messages) { message in
                            GlimmerHistoryEventRow(message: message)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
        }
        .navigationTitle(Text("glimmerHistory.history.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("matching.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.retry") {
                Task { await loadMessages() }
            }
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "matching.error.unknown"))
        }
        .task {
            await loadMessages()
        }
    }

    private func loadMessages() async {
        isLoading = true
        defer { isLoading = false }

        do {
            messages = try await GlimmerMessage.getAll(glimmerId: glimmer.id)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct GlimmerHistoryEventRow: View {
    let message: GlimmerMessage

    var body: some View {
        Group {
            if message.type == "message", let role = message.role {
                ConversationMessageRow(
                    role: role == "user" ? .user : .assistant,
                    content: message.content ?? ""
                )
            } else if message.type == "tool_result", resonanceMatches.isEmpty == false {
                StarSeaResonanceMatchesView(matches: resonanceMatches)
            }
        }
    }

    private var resonanceMatches: [StarSeaStreamService.ResonanceMatch] {
        guard
            let object = message.payload.objectValue,
            object["tool"]?.stringValue == "resonance_match",
            let items = object["items"]?.arrayValue
        else {
            return []
        }

        return items.compactMap { item in
            guard let object = item.objectValue else { return nil }
            let name = object["name"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let line = object["line"]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !name.isEmpty, !line.isEmpty else { return nil }
            return StarSeaStreamService.ResonanceMatch(name: name, line: line)
        }
    }
}

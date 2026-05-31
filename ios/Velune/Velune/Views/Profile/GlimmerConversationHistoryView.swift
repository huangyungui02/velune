import SwiftUI

struct GlimmerConversationHistoryView: View {
    let glimmer: Glimmer

    @State private var messages: [GlimmerMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var shouldPauseAutoScrollDuringStreaming = false

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
                StarSeaConversationMessageList(
                    events: timelineEvents,
                    isOptionsDisabled: true,
                    isStreaming: false,
                    shouldPauseAutoScrollDuringStreaming: $shouldPauseAutoScrollDuringStreaming,
                    showsOptions: false,
                    onDismissComposerFocus: {},
                    onSelectOption: { _ in }
                )
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

    private var timelineEvents: [StarSeaTimelineEvent] {
        messages.compactMap { message in
            if message.type == "message", let role = message.role {
                return .message(
                    StarSeaMessage(
                        id: message.id,
                        role: role == "user" ? .user : .assistant,
                        content: message.content ?? ""
                    )
                )
            }

            let matches = resonanceMatches(for: message)
            guard message.type == "tool_result", !matches.isEmpty else { return nil }
            return .resonanceMatches(id: message.id, matches: matches)
        }
    }

    private func resonanceMatches(for message: GlimmerMessage) -> [StarSeaStreamService.ResonanceMatch] {
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
            return StarSeaStreamService.ResonanceMatch(
                name: name,
                line: line,
                soulerId: uuidValue(for: ["soulerId", "souler_id"], in: object),
                resolutionRequestId: uuidValue(
                    for: ["resolutionRequestId", "resolution_request_id"],
                    in: object
                ),
                resolutionStatus: stringValue(for: ["resolutionStatus", "resolution_status"], in: object)
            )
        }
    }

    private func uuidValue(for keys: [String], in object: [String: JSONValue]) -> UUID? {
        guard let value = stringValue(for: keys, in: object) else { return nil }
        return UUID(uuidString: value)
    }

    private func stringValue(for keys: [String], in object: [String: JSONValue]) -> String? {
        keys
            .compactMap { object[$0]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first { !$0.isEmpty }
    }
}

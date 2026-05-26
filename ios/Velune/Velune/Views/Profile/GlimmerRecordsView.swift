import SwiftUI

struct GlimmerRecordsView: View {
    @State private var glimmers: [Glimmer] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            BackgroundView()

            if isLoading, glimmers.isEmpty {
                ProgressView("common.loading")
                    .tint(UITheme.primaryText)
            } else if glimmers.isEmpty {
                ContentUnavailableView(
                    "glimmerHistory.empty.noGlimmers",
                    systemImage: "sparkles",
                    description: Text("glimmerHistory.empty.noGlimmers.subtitle")
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(glimmers) { glimmer in
                            NavigationLink {
                                GlimmerDetailView(glimmer: glimmer)
                            } label: {
                                GlimmerRecordCard(glimmer: glimmer)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding()
                }
                .refreshable {
                    await loadGlimmers()
                }
            }
        }
        .navigationTitle(Text("glimmerHistory.title"))
        .navigationBarTitleDisplayMode(.inline)
        .alert("matching.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.retry") {
                Task { await loadGlimmers() }
            }
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "matching.error.unknown"))
        }
        .task {
            await loadGlimmers()
        }
    }

    private func loadGlimmers() async {
        isLoading = true
        defer { isLoading = false }

        do {
            glimmers = try await Glimmer.getAll()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct GlimmerRecordCard: View {
    let glimmer: Glimmer

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(glimmer.createdAt.formatted(date: .abbreviated, time: .shortened))
                .font(.caption)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.secondaryText)

            Text(glimmer.content)
                .font(.body)
                .fontDesign(.serif)
                .lineSpacing(6)
                .foregroundStyle(UITheme.primaryText)
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

private struct GlimmerDetailView: View {
    let glimmer: Glimmer

    var body: some View {
        ZStack {
            BackgroundView()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text(glimmer.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .fontDesign(.serif)
                        .foregroundStyle(UITheme.secondaryText)

                    Text(glimmer.content)
                        .font(.title3)
                        .fontDesign(.serif)
                        .lineSpacing(8)
                        .foregroundStyle(UITheme.primaryText)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(22)
            }
        }
        .navigationTitle(Text("glimmerHistory.detail.title"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    GlimmerConversationHistoryView(glimmer: glimmer)
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
                .accessibilityLabel(Text("glimmerHistory.history.title"))
            }
        }
    }
}

private struct GlimmerConversationHistoryView: View {
    let glimmer: Glimmer

    @State private var messages: [GlimmerMessage] = []
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ZStack {
            StarryBackgroundView()

            if isLoading, messages.isEmpty {
                ProgressView("common.loading")
                    .tint(UITheme.primaryText)
            } else if messages.isEmpty {
                ContentUnavailableView(
                    "glimmerHistory.history.empty",
                    systemImage: "clock.arrow.circlepath"
                )
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(messages) { message in
                            GlimmerHistoryEventRow(message: message)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
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

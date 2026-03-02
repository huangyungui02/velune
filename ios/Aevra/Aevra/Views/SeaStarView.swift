import Supabase
import SwiftData
import SwiftUI

struct SeaStarView: View {
    private enum Destination: Equatable {
        case seastar
        case chat(Resonance)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var text = ""
    @State private var isNavigatingToMatching = false
    @State private var isPresented = false
    @State private var isSidebarPresented = false
    @State private var destination: Destination = .seastar
    @State private var resonances: [Resonance] = []
    @State private var isLoadingResonances = false
    @State private var resonanceMenuError: String?
    @State private var manager = MatchingManager.shared

    var body: some View {
        NavigationStack {
            ZStack(alignment: .leading) {
                mainContent
                    .disabled(isSidebarPresented)
                    .blur(radius: isSidebarPresented ? 1.5 : 0)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) {
                            Button {
                                withAnimation(.easeInOut(duration: 0.22)) {
                                    isSidebarPresented.toggle()
                                }
                            } label: {
                                Image(systemName: "line.3.horizontal")
                            }
                            .accessibilityLabel(Text("seastar.action.resonances"))
                        }

                        if isSeaStarDestination {
                            ToolbarItem(placement: .topBarTrailing) {
                                NavigationLink {
                                    ProfileView()
                                } label: {
                                    Image(systemName: "house.fill")
                                }
                            }
                        }
                    }
                    .task {
                        await loadResonancesForMenu()
                    }

                if isSidebarPresented {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                isSidebarPresented = false
                            }
                        }
                        .transition(.opacity)

                    sidebarView
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.22), value: isSidebarPresented)
            .navigationBarTitleDisplayMode(.inline)
        }
        .navigationDestination(isPresented: $isNavigatingToMatching) {
            MatchingView()
        }
        .fullScreenCover(isPresented: $isPresented) {
            ComposeView(text: $text, onSend: send)
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch destination {
        case .seastar:
            ZStack {
                StarryBackgroundView()

                VStack {
                    Spacer()

                    VerseView(textKey: "seastar.hero.verse")

                    Spacer()

                    magicButtonView
                }
            }
        case let .chat(resonance):
            ChatView(
                soulerId: resonance.soulerId,
                soulerName: resonance.soulerName
            )
        }
    }

    private var isSeaStarDestination: Bool {
        if case .seastar = destination {
            return true
        }
        return false
    }

    private var sidebarView: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                destination = .seastar
                withAnimation(.easeInOut(duration: 0.2)) {
                    isSidebarPresented = false
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: isSeaStarDestination ? "checkmark" : "sparkles")
                    Text("SeaStar")
                        .font(.body.weight(.semibold))
                        .fontDesign(.serif)
                }
                .foregroundStyle(UITheme.primaryText)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    isSeaStarDestination ? .white.opacity(0.18) : .clear,
                    in: .rect(cornerRadius: 12)
                )
            }
            .buttonStyle(.plain)

            Divider()
                .overlay(.white.opacity(0.12))
                .padding(.bottom, 2)

            Group {
                if let resonanceMenuError {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(resonanceMenuError)
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)

                        Button("common.retry") {
                            Task {
                                await loadResonancesForMenu()
                            }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 8)
                } else if isLoadingResonances, resonances.isEmpty {
                    HStack(spacing: 8) {
                        ProgressView()
                        Text("common.loading")
                            .font(.footnote)
                            .foregroundStyle(UITheme.secondaryText)
                    }
                    .padding(.top, 8)
                } else if resonances.isEmpty {
                    Text("resonance.empty")
                        .font(.footnote)
                        .foregroundStyle(UITheme.secondaryText)
                        .padding(.top, 8)
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(resonances) { resonance in
                                Button {
                                    destination = .chat(resonance)
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        isSidebarPresented = false
                                    }
                                } label: {
                                    HStack(spacing: 8) {
                                        HStack(spacing: 8) {
                                            Image(systemName: selectedResonanceId == resonance.id ? "checkmark" : "message")
                                                .font(.caption.weight(.semibold))
                                            Text(resonance.soulerName)
                                                .lineLimit(1)
                                                .font(.body.weight(.medium))
                                                .fontDesign(.serif)
                                        }
                                        .foregroundStyle(UITheme.primaryText)

                                        Spacer(minLength: 8)

                                        Text(resonance.updatedAt, format: .relative(presentation: .named).locale(locale))
                                            .font(.caption)
                                            .foregroundStyle(UITheme.secondaryText)
                                            .lineLimit(1)
                                            .monospacedDigit()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        selectedResonanceId == resonance.id ? .white.opacity(0.15) : .clear,
                                        in: .rect(cornerRadius: 12)
                                    )
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(width: 320, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial, in: .rect(cornerRadius: 22))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 1)
        )
        .padding(.leading, 10)
        .padding(.vertical, 8)
    }

    private var selectedResonanceId: UUID? {
        if case let .chat(resonance) = destination {
            return resonance.id
        }
        return nil
    }

    private var magicButtonView: some View {
        Group {
            if manager.isMatching {
                HStack(spacing: 12) {
                    MatchingWaveIcon()

                    Text("matching.status.listening")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(UITheme.secondaryText)
                        .tracking(2)
                }
                .padding()
                .glassEffect(in: .capsule)
            } else if text.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "sparkles")

                    Text("seastar.prompt.glimmerWithin")
                        .foregroundStyle(UITheme.primaryText)
                        .font(.body)
                        .fontDesign(.serif)
                }
                .padding()
                .glassEffect(in: .capsule)
            } else {
                draftPreviewField
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 20))
                    .contentShape(.rect)
                    .highPriorityGesture(
                        TapGesture().onEnded {
                            isPresented = true
                        }
                    )
                    .padding(.horizontal)
            }
        }
        .onTapGesture {
            if manager.isMatching {
                isNavigatingToMatching = true
            } else {
                isPresented = true
            }
        }
    }

    private var draftPreviewField: some View {
        TextField("", text: .constant(text), axis: .vertical)
            .font(.body)
            .fontDesign(.serif)
            .lineLimit(1 ... 5)
            .foregroundStyle(UITheme.primaryText)
            .frame(maxWidth: .infinity, alignment: .leading)
            .textFieldStyle(.plain)
    }

    // MARK: - Actions

    @MainActor
    private func loadResonancesForMenu() async {
        if isLoadingResonances { return }

        isLoadingResonances = true
        defer { isLoadingResonances = false }

        do {
            resonances = try await Resonance.getPage(limit: 20, offset: 0)
            resonanceMenuError = nil
        } catch {
            resonanceMenuError = error.localizedDescription
            resonances = []
        }
    }

    private func send() {
        let input = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !input.isEmpty else { return }
        manager.startMatching(text: text, context: context)
        text = ""
        isNavigatingToMatching = true
    }
}

// MARK: - Verse View

private struct VerseView: View {
    let textKey: LocalizedStringKey

    var body: some View {
        VStack {
            Spacer()

            Text(textKey)
                .font(.title2)
                .fontDesign(.serif)
                .multilineTextAlignment(.center)
                .lineSpacing(14)
                .tracking(2)
                .foregroundStyle(UITheme.primaryText.opacity(0.85))
                .shadow(color: .white.opacity(0.12), radius: 16)
                .shadow(color: .white.opacity(0.06), radius: 32)

            Spacer()
        }
    }
}

// MARK: - Compose View

private struct ComposeView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var text: String
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                TextField("seastar.prompt.glimmerWithin", text: $text, axis: .vertical)
                    .focused($isFocused)
                    .font(.body)
                    .fontDesign(.serif)
                    .lineSpacing(6)
                    .padding(24)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Spacer()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(white: 0.06),
                        Color(white: 0.12),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("glimmer.title")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }) {
                        Image(systemName: "xmark")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(UITheme.secondaryText)
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: {
                        onSend()
                        dismiss()
                    }) {
                        Image(systemName: "checkmark")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(UITheme.primaryText)
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    .opacity(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.3 : 1)
                }
            }
        }
        .onAppear {
            isFocused = true
        }
    }
}

#Preview {
    SeaStarView()
}

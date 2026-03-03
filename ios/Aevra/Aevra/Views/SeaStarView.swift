import Supabase
import SwiftData
import SwiftUI

struct SeaStarView: View {
    private enum SeaStarStage: Equatable {
        case verse
        case matching
    }

    private enum Destination: Equatable {
        case seastar
        case chat(Resonance)
    }

    @Environment(\.modelContext) private var context
    @Environment(\.locale) private var locale
    @State private var text = ""
    @State private var isPresented = false
    @State private var isSidebarPresented = false
    @State private var destination: Destination = .seastar
    @State private var stage: SeaStarStage = .verse
    @State private var resonances: [Resonance] = []
    @State private var isLoadingResonances = false
    @State private var resonanceMenuError: String?
    @State private var manager = MatchingManager.shared
    @State private var showError = false
    @State private var shouldRecoverToVerseAfterError = false
    @State private var currentPage: CardID? = .glimmer
    @State private var chatRoute: EchoChatRoute?
    @State private var sidebarDragOffset: CGFloat = 0

    private let sidebarWidth: CGFloat = 320

    var body: some View {
        ZStack(alignment: .leading) {
            NavigationStack {
                mainContent
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
                                ZStack(alignment: .topTrailing) {
                                    NavigationLink {
                                        ProfileView()
                                    } label: {
                                        Image(systemName: "house.fill")
                                    }
                                }
                            }

                            if stage == .matching {
                                if manager.isMatching && !hasEchoes {
                                    ToolbarItem(placement: .status) {
                                        listeningToolbarChip
                                    }
                                } else {
                                    if hasEchoes {
                                        ToolbarItem(placement: .bottomBar) {
                                            Spacer()
                                        }

                                        ToolbarItem(placement: .bottomBar) {
                                            if shouldShowArchiveButton {
                                                archiveButton
                                            } else if shouldShowWaveButton {
                                                liquidSplitWaveIcon
                                            }
                                        }
                                    }

                                    if hasEchoes {
                                        ToolbarItem(placement: .status) {
                                            CardPagerIndicatorView(echoes: echoes, currentPage: $currentPage)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .task {
                        await loadResonancesForMenu()
                    }
                    .navigationBarTitleDisplayMode(.inline)
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
            .offset(x: sidebarOpenOffset)
            .disabled(sidebarProgress > 0.01)

            if sidebarProgress > 0.001 {
                Color.black.opacity(0.3 * sidebarProgress)
                    .ignoresSafeArea()
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isSidebarPresented = false
                        }
                    }
            }

            sidebarView
                .offset(x: sidebarOpenOffset - sidebarWidth)
        }
        .simultaneousGesture(sidebarGesture)
        .animation(.easeInOut(duration: 0.22), value: isSidebarPresented)
        .animation(.interactiveSpring(response: 0.22, dampingFraction: 0.9), value: sidebarDragOffset)
        .fullScreenCover(isPresented: $isPresented) {
            ComposeView(text: $text, onSend: send)
        }
        .onChange(of: manager.errorMessage) { _, newValue in
            if stage == .matching, newValue != nil {
                shouldRecoverToVerseAfterError = true
            }
            showError = newValue != nil
        }
        .onChange(of: showError) { _, isShowing in
            if !isShowing, shouldRecoverToVerseAfterError {
                recoverToVerseAfterError()
            }
        }
        .alert("matching.error.title", isPresented: $showError) {
            Button("common.ok", role: .cancel) {
                recoverToVerseAfterError()
            }
        } message: {
            if let errorMessage = manager.errorMessage {
                Text(errorMessage)
            } else {
                Text("matching.error.unknown")
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        switch destination {
        case .seastar:
            ZStack {
                StarryBackgroundView()

                if stage == .matching {
                    matchingContent
                } else {
                    VStack {
                        Spacer()

                        VerseView(textKey: "seastar.hero.verse")

                        Spacer()

                        magicButtonView
                    }
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
        .frame(width: sidebarWidth, alignment: .topLeading)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
        .overlay(
            Rectangle()
                .fill(.white.opacity(0.14))
                .frame(width: 1),
            alignment: .trailing
        )
    }

    private var sidebarOpenOffset: CGFloat {
        let base = isSidebarPresented ? sidebarWidth : 0
        return min(max(base + sidebarDragOffset, 0), sidebarWidth)
    }

    private var sidebarProgress: CGFloat {
        guard sidebarWidth > 0 else { return 0 }
        return sidebarOpenOffset / sidebarWidth
    }

    private var sidebarGesture: some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .global)
            .onChanged { value in
                let isEdgeSwipe = value.startLocation.x <= 28
                if !isSidebarPresented && !isEdgeSwipe { return }

                if isSidebarPresented {
                    sidebarDragOffset = min(0, value.translation.width)
                } else {
                    sidebarDragOffset = max(0, value.translation.width)
                }
            }
            .onEnded { value in
                let isEdgeSwipe = value.startLocation.x <= 28
                guard isSidebarPresented || isEdgeSwipe else {
                    sidebarDragOffset = 0
                    return
                }

                let predicted = (isSidebarPresented ? sidebarWidth : 0) + value.predictedEndTranslation.width
                let shouldOpen = predicted > sidebarWidth * 0.45

                withAnimation(.easeInOut(duration: 0.22)) {
                    isSidebarPresented = shouldOpen
                }
                sidebarDragOffset = 0
            }
    }

    private var selectedResonanceId: UUID? {
        if case let .chat(resonance) = destination {
            return resonance.id
        }
        return nil
    }

    private var echoes: [Echo] {
        (manager.currentGlimmer?.echoes ?? [])
            .sorted { $0.createdAt < $1.createdAt }
    }

    private var hasEchoes: Bool {
        !echoes.isEmpty
    }

    private var shouldShowArchiveButton: Bool {
        stage == .matching && !manager.isMatching && manager.currentGlimmer?.status == "complete"
    }

    private var shouldShowWaveButton: Bool {
        stage == .matching && manager.isMatching && hasEchoes
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
                stage = .matching
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
        manager.startMatching(text: input, context: context)
        text = ""
        currentPage = .glimmer
        stage = .matching
    }

    private func archiveCurrentGlimmer() {
        guard shouldShowArchiveButton else { return }
        manager.reset()
        currentPage = .glimmer
        stage = .verse
    }

    private func recoverToVerseAfterError() {
        manager.reset()
        stage = .verse
        currentPage = .glimmer
        shouldRecoverToVerseAfterError = false
    }
}

extension SeaStarView {
    private var matchingContent: some View {
        VStack(spacing: 16) {
            CardPagerView(
                echoes: echoes,
                currentPage: $currentPage,
                autoSwitchToFirstEcho: true
            ) { maxCardHeight in
                GlimmerCardView(content: manager.text, maxCardHeight: maxCardHeight)
            } echoCard: { echo, maxCardHeight in
                EchoCardView(
                    echo: echo,
                    glimmerContent: manager.text,
                    maxCardHeight: maxCardHeight,
                    onOpenChat: { route in
                        chatRoute = route
                    }
                )
            }
            .frame(maxHeight: .infinity, alignment: .top)
            .padding(.vertical)
        }
    }

    private var listeningToolbarChip: some View {
        HStack(spacing: 12) {
            MatchingWaveIcon()

            Text("matching.status.listening")
                .font(.footnote.weight(.medium))
                .foregroundStyle(UITheme.primaryText)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .fixedSize(horizontal: true, vertical: false)
    }

    private var liquidSplitWaveIcon: some View {
        MatchingWaveIcon()
            .frame(width: 24, height: 24)
    }

    private var archiveButton: some View {
        Button(action: archiveCurrentGlimmer) {
            archiveChip
        }
        .buttonStyle(.plain)
    }

    private var archiveChip: some View {
        Image(systemName: "sparkles")
            .font(.footnote.weight(.semibold))
            .foregroundStyle(UITheme.primaryText)
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

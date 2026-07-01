import SwiftUI

struct StarSeaResonanceMatchesView: View {
    let matches: [StarSeaStreamService.ResonanceMatch]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("starsea.resonance.title")
                .font(.system(size: 11, weight: .light))
                .tracking(2.0)
                .foregroundStyle(UITheme.tertiaryText.opacity(0.6))
                .padding(.leading, 6)

            ForEach(matches) { match in
                StarSeaResonanceMatchRow(match: match)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct StarSeaResonanceMatchRow: View {
    let match: StarSeaStreamService.ResonanceMatch

    @State private var destination: SoulerDestination?
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if canOpen {
                Button {
                    Task { await openSouler() }
                } label: {
                    rowContent
                }
                .buttonStyle(.plain)
            } else {
                rowContent
            }
        }
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case let .souler(id):
                SoulerView(soulerId: id)
            case let .resolution(requestId, name):
                SoulerResolutionView(requestId: requestId, name: name)
            }
        }
        .alert("matching.error.title", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("common.ok", role: .cancel) {}
        } message: {
            Text(errorMessage ?? String(localized: "matching.error.unknown"))
        }
    }

    private var canOpen: Bool {
        match.soulerId != nil || match.resolutionRequestId != nil
    }

    private var rowContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(match.whisper)
                .font(.system(size: 14, weight: .light, design: .serif))
                .lineSpacing(6)
                .tracking(0.5)
                .foregroundStyle(UITheme.primaryText.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)

            Text("— \(match.name)")
                .font(.system(size: 12, weight: .light, design: .serif))
                .tracking(1.0)
                .foregroundStyle(UITheme.secondaryText.opacity(0.75))
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial.opacity(0.18),
            in: .rect(cornerRadius: 16, style: .continuous)
        )
    }

    private func openSouler() async {
        if let soulerId = match.soulerId {
            destination = .souler(id: soulerId)
            return
        }

        if let requestId = match.resolutionRequestId {
            destination = .resolution(requestId: requestId, name: match.name)
            return
        }

        errorMessage = String(localized: "matching.error.unknown")
    }
}

private enum SoulerDestination: Identifiable, Hashable {
    case souler(id: UUID)
    case resolution(requestId: UUID, name: String)

    var id: String {
        switch self {
        case let .souler(id):
            "souler-\(id.uuidString)"
        case let .resolution(requestId, _):
            "resolution-\(requestId.uuidString)"
        }
    }
}

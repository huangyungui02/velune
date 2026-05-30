import SwiftUI

struct StarSeaResonanceMatchesView: View {
    let matches: [StarSeaStreamService.ResonanceMatch]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        Button {
            Task { await openSouler() }
        } label: {
            rowContent
        }
        .buttonStyle(.plain)
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

    private var rowContent: some View {
        HStack(spacing: 16) {
            avatar

            VStack(alignment: .leading, spacing: 6) {
                Text(match.name)
                    .font(.system(size: 14.5, weight: .light, design: .serif))
                    .tracking(1.0)
                    .foregroundStyle(UITheme.primaryText.opacity(0.92))
                    .lineLimit(1)

                Text(match.line)
                    .font(.system(size: 12, weight: .light, design: .serif))
                    .lineSpacing(5)
                    .tracking(0.5)
                    .foregroundStyle(UITheme.secondaryText.opacity(0.68))
                    .lineLimit(2)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .light))
                .foregroundStyle(UITheme.tertiaryText.opacity(0.6))
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            .ultraThinMaterial.opacity(0.20),
            in: .rect(cornerRadius: 16, style: .continuous)
        )
        .background {
            RadialGradient(
                colors: [
                    UITheme.glimmerGlow.opacity(0.04),
                    .clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 180
            )
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [.white.opacity(0.04), .white.opacity(0.005)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 0.5
                )
        }
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

    private var avatar: some View {
        let initial = String(match.name.prefix(1))
        let hue = Double(abs(match.name.hashValue) % 360) / 360.0

        return ZStack {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: hue, saturation: 0.24, brightness: 0.65).opacity(0.24),
                            Color(hue: hue, saturation: 0.12, brightness: 0.82).opacity(0.08)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                      )
                )
                .frame(width: 45, height: 60)

            Text(initial)
                .font(.system(size: 16, weight: .light, design: .serif))
                .foregroundStyle(UITheme.primaryText.opacity(0.85))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        }
        .frame(width: 45, height: 60)
        .shadow(color: .black.opacity(0.15), radius: 4, x: 0, y: 2)
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

import SwiftUI

struct SoulerResolutionView: View {
    let requestId: UUID
    let name: String

    @State private var statusText = String(localized: "souler.resolution.status.preparing")
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var resolvedSoulerId: UUID?

    var body: some View {
        Group {
            if let resolvedSoulerId {
                SoulerView(soulerId: resolvedSoulerId)
            } else {
                placeholderContent
            }
        }
        .navigationTitle(name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task(id: requestId) {
            await pollResolution()
        }
    }

    private var placeholderContent: some View {
        ZStack {
            BackgroundView()

            ScrollView {
                VStack(spacing: 28) {
                    SoulerResolutionPortrait(name: name)
                        .frame(width: 128)

                    VStack(spacing: 12) {
                        Text(name)
                            .font(.title2.weight(.semibold))
                            .fontDesign(.serif)
                            .foregroundStyle(UITheme.primaryText)
                            .multilineTextAlignment(.center)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)

                        Text(errorMessage == nil ? statusText : String(localized: "souler.resolution.status.failed"))
                            .font(.body)
                            .fontDesign(.serif)
                            .lineSpacing(6)
                            .foregroundStyle(UITheme.secondaryText.opacity(0.82))
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: 320)
                    }

                    if let errorMessage {
                        VStack(spacing: 14) {
                            Text(errorMessage)
                                .font(.footnote)
                                .foregroundStyle(UITheme.tertiaryText)
                                .multilineTextAlignment(.center)
                                .frame(maxWidth: 320)

                            Button("common.retry") {
                                Task { await pollResolution() }
                            }
                            .buttonStyle(.bordered)
                            .tint(UITheme.primaryText)
                        }
                    } else {
                        ProgressView()
                            .controlSize(.regular)
                            .tint(UITheme.secondaryText.opacity(0.75))
                    }
                }
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 24)
                .padding(.top, 56)
                .padding(.bottom, 32)
            }
        }
    }

    @MainActor
    private func pollResolution() async {
        if isLoading { return }

        isLoading = true
        errorMessage = nil
        statusText = String(localized: "souler.resolution.status.preparing")
        defer { isLoading = false }

        do {
            while !Task.isCancelled {
                let status = try await StarSeaStreamService.resolutionStatus(requestId: requestId)
                statusText = message(for: status.status)

                if let soulerId = status.soulerId, status.status == "complete" {
                    resolvedSoulerId = soulerId
                    return
                }

                if status.status == "failed" {
                    errorMessage = status.error ?? String(localized: "matching.error.unknown")
                    return
                }

                try await Task.sleep(for: .seconds(1))
            }
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func message(for status: String) -> String {
        switch status {
        case "queued":
            String(localized: "souler.resolution.status.queued")
        case "processing":
            String(localized: "souler.resolution.status.processing")
        case "complete":
            String(localized: "souler.resolution.status.complete")
        case "failed":
            String(localized: "souler.resolution.status.failed")
        default:
            String(localized: "souler.resolution.status.preparing")
        }
    }
}

private struct SoulerResolutionPortrait: View {
    let name: String

    private var initial: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? "?"
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(.white.opacity(0.06))

            Text(initial)
                .font(.largeTitle.weight(.semibold))
                .fontDesign(.serif)
                .foregroundStyle(UITheme.tertiaryText)
        }
        .aspectRatio(3 / 4, contentMode: .fit)
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(.white.opacity(0.12), lineWidth: 0.7)
        }
        .shadow(color: .black.opacity(0.12), radius: 12, y: 6)
    }
}

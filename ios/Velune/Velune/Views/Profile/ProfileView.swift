import SwiftUI

private enum ProfileRoute: Hashable {
    case glimmers
    case settings
}

struct ProfileView: View {
    @State private var path: [ProfileRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                BackgroundView()

                VStack(spacing: 12) {
                    NavigationLink(value: ProfileRoute.glimmers) {
                        ProfileActionRow(
                            title: "glimmerHistory.title",
                            systemImage: "sparkles"
                        )
                    }
                    .buttonStyle(.plain)

                    Spacer()
                }
                .padding()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink(value: ProfileRoute.settings) {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel(Text("settings.title"))
                }
            }
            .navigationDestination(for: ProfileRoute.self) { route in
                switch route {
                case .glimmers:
                    GlimmerRecordsView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .toolbar(path.isEmpty ? .automatic : .hidden, for: .tabBar)
    }
}

private struct ProfileActionRow: View {
    let title: LocalizedStringKey
    let systemImage: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.body.weight(.medium))
                .frame(width: 28, height: 28)
                .foregroundStyle(UITheme.primaryText)

            Text(title)
                .font(.body)
                .fontDesign(.serif)
                .foregroundStyle(UITheme.primaryText)

            Spacer()

            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(UITheme.secondaryText)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(.white.opacity(0.06), in: .rect(cornerRadius: 16))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(.white.opacity(0.08), lineWidth: 0.5)
        }
    }
}

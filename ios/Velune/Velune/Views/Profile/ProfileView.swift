import SwiftUI

private enum ProfileRoute: Hashable {
    case settings
}

struct ProfileView: View {
    @State private var path: [ProfileRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                BackgroundView()
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
                case .settings:
                    SettingsView()
                }
            }
        }
        .toolbar(path.isEmpty ? .automatic : .hidden, for: .tabBar)
    }
}

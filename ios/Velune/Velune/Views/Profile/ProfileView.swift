import SwiftUI

enum ProfileRoute: Hashable {
    case settings
    case glimmerDetail(id: UUID)
}

struct ProfileView: View {
    @State private var path: [ProfileRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            GlimmerRecordsView()
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: ProfileRoute.settings) {
                            Image(systemName: "gearshape")
                        }
                        .accessibilityLabel(Text("settings.title"))
                    }
                }
        }
        .toolbar(path.isEmpty ? .automatic : .hidden, for: .tabBar)
    }
}

import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable {
        case starSea
        case resonance
        case profile
    }

    @State private var selectedTab: AppTab = .starSea
    @State private var composeRequestID = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StarSeaView(composeRequestID: $composeRequestID)
                .tabItem {
                    Label("app.tab.starsea", systemImage: "sparkles")
                }
                .tag(AppTab.starSea)

            ResonanceView(onOpenGlimmerComposer: openGlimmerComposer)
                .tabItem {
                    Label("app.tab.resonance", systemImage: "bubble.left.and.bubble.right")
                }
                .tag(AppTab.resonance)

            ProfileView(onOpenGlimmerComposer: openGlimmerComposer)
            .tabItem {
                Label("app.tab.profile", systemImage: "person.crop.circle")
            }
            .tag(AppTab.profile)
        }
    }

    private func openGlimmerComposer() {
        selectedTab = .starSea
        composeRequestID += 1
    }
}

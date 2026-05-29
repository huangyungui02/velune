import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable {
        case starSea
        case reading
        case profile
    }

    @State private var selectedTab: AppTab = .starSea

    var body: some View {
        TabView(selection: $selectedTab) {
            StarSeaView()
                .tabItem {
                    Label("app.tab.starsea", systemImage: "sparkles")
                }
                .tag(AppTab.starSea)

            ReadingView()
                .tabItem {
                    Label("app.tab.reading", systemImage: "book.closed")
                }
                .tag(AppTab.reading)

            ProfileView()
            .tabItem {
                Label("app.tab.profile", systemImage: "house")
            }
            .tag(AppTab.profile)
        }
    }
}

import SwiftUI

struct ContentView: View {
    private enum AppTab: Hashable {
        case chat
        case explore
        case bookshelf
        case profile
    }

    @State private var selectedTab: AppTab = .chat
    @State private var composeRequestID = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            StarSeaView(composeRequestID: $composeRequestID)
                .tabItem {
                    Label("app.tab.chat", systemImage: "message")
                }
                .tag(AppTab.chat)

            ExploreView()
                .tabItem {
                    Label("app.tab.explore", systemImage: "safari")
                }
                .tag(AppTab.explore)

            BookshelfView()
                .tabItem {
                    Label("app.tab.bookshelf", systemImage: "books.vertical")
                }
                .tag(AppTab.bookshelf)

            ProfileView(onOpenGlimmerComposer: openGlimmerComposer)
            .tabItem {
                Label("app.tab.profile", systemImage: "person.crop.circle")
            }
            .tag(AppTab.profile)
        }
    }

    private func openGlimmerComposer() {
        selectedTab = .chat
        composeRequestID += 1
    }
}

import SwiftData
import SwiftUI

@main
struct VeluneApp: App {
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    private let dataContainer = DataContainer()
    private let transientDataContainer = DataContainer(inMemoryOnly: true)

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                } else {
                    SignView()
                }
            }
            .tint(UITheme.accent)
            .preferredColorScheme(.dark)
            .task(id: authManager.currentUserId) {
                await subscriptionManager.bootstrap(userId: authManager.currentUserId)
            }
            .animation(.easeInOut, value: authManager.isAuthenticated)
            .animation(.easeInOut, value: authManager.isAnonymous)
        }
        .modelContainer(authManager.isAnonymous ? transientDataContainer.modelContainer : dataContainer.modelContainer)
    }
}

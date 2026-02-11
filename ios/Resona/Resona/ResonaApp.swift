import SwiftData
import SwiftUI

@main
struct ResonaApp: App {
    @State private var authManager = AuthManager.shared
    let dataContainer = DataContainer()

    var body: some Scene {
        WindowGroup {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                } else {
                    SignView()
                }
            }
            .preferredColorScheme(.dark)
            .animation(.easeInOut, value: authManager.isAuthenticated)
        }
        .modelContainer(dataContainer.modelContainer)
    }
}

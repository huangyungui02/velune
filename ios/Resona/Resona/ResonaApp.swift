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
            .animation(.easeInOut, value: authManager.isAuthenticated)
            .preferredColorScheme(.dark)
        }
        .modelContainer(dataContainer.modelContainer)
    }
}

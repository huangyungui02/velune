import SwiftData
import SwiftUI

@main
struct VeluneApp: App {
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.systemDefault.rawValue
    private let dataContainer = DataContainer()
    private let transientDataContainer = DataContainer(inMemoryOnly: true)

    init() {
        (AppLanguage(rawValue: UserDefaults.standard.string(forKey: AppLanguage.storageKey) ?? "") ?? .systemDefault)
            .applyAsPreferredLanguage()
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .systemDefault
    }

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
            .environment(\.locale, appLanguage.locale)
            .onChange(of: appLanguageRawValue) { _, newValue in
                (AppLanguage(rawValue: newValue) ?? .systemDefault).applyAsPreferredLanguage()
            }
            .task(id: authManager.currentUserId) {
                await subscriptionManager.bootstrap(userId: authManager.currentUserId)
            }
            .animation(.easeInOut, value: authManager.isAuthenticated)
            .animation(.easeInOut, value: authManager.isAnonymous)
        }
        .modelContainer(authManager.isAnonymous ? transientDataContainer.modelContainer : dataContainer.modelContainer)
    }
}

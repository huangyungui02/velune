import SwiftData
import SwiftUI

@main
struct AevraApp: App {
    @State private var authManager = AuthManager.shared
    @AppStorage(AppLanguage.storageKey) private var appLanguageRawValue = AppLanguage.systemDefault.rawValue
    let dataContainer = DataContainer()

    init() {
        UITheme.registerFonts()
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
            .animation(.easeInOut, value: authManager.isAuthenticated)
        }
        .modelContainer(dataContainer.modelContainer)
    }
}

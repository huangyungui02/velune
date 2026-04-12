import OSLog
import SwiftData
import SwiftUI

@main
struct VeluneApp: App {
    @Environment(\.scenePhase) private var scenePhase
    @State private var authManager = AuthManager.shared
    @State private var subscriptionManager = SubscriptionManager.shared
    private let launchFailure: AppLaunchFailure?
    private let dataContainer: DataContainer?
    private let transientDataContainer: DataContainer?

    init() {
        (launchFailure, dataContainer, transientDataContainer) = Self.bootstrap()
    }

    var body: some Scene {
        WindowGroup {
            rootView
                .tint(UITheme.accent)
                .preferredColorScheme(.dark)
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if let launchFailure {
            LaunchFailureView(failure: launchFailure)
        } else if let dataContainer, let transientDataContainer {
            Group {
                if authManager.isAuthenticated {
                    ContentView()
                } else {
                    SignView()
                }
            }
            .task(id: authManager.currentUserId) {
                await subscriptionManager.bootstrap(userId: authManager.currentUserId)
            }
            .task {
                await authManager.syncInstallationMetadataIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else {
                    return
                }
                Task { await authManager.syncInstallationMetadataIfNeeded() }
            }
            .animation(.easeInOut, value: authManager.isAuthenticated)
            .animation(.easeInOut, value: authManager.isAnonymous)
            .modelContainer(authManager.isAnonymous ? transientDataContainer.modelContainer : dataContainer.modelContainer)
        }
    }

    private static func bootstrap() -> (AppLaunchFailure?, DataContainer?, DataContainer?) {
        if let configurationError = Backend.configurationError {
            return (AppLaunchFailure(error: configurationError), nil, nil)
        }

        do {
            return (nil, try DataContainer(), try DataContainer(inMemoryOnly: true))
        } catch {
            AppLogger.storage.error("persistent store bootstrap failed: \(error.localizedDescription, privacy: .public)")
            return (AppLaunchFailure(error: AppError.persistenceUnavailable), nil, nil)
        }
    }
}

import Foundation
import OSLog
import Supabase

nonisolated enum Backend {
    private final class BundleLocator {}
    private static let infoBundle = Bundle(for: BundleLocator.self)

    struct Configuration {
        let supabaseURL: URL
        let supabaseKey: String
        let apiBaseURL: URL
    }

    private static let logger = AppLogger.app
    private static let configurationResult = loadConfiguration()
    private static let client: SupabaseClient? = {
        guard case let .success(configuration) = configurationResult else {
            return nil
        }

        return SupabaseClient(
            supabaseURL: configuration.supabaseURL,
            supabaseKey: configuration.supabaseKey,
            options: SupabaseClientOptions(
                auth: SupabaseClientOptions.AuthOptions(
                    autoRefreshToken: true,
                    emitLocalSessionAsInitialSession: true
                )
            )
        )
    }()

    static var configurationError: AppError? {
        guard case let .failure(error) = configurationResult else { return nil }
        return error
    }

    static var supabaseIfAvailable: SupabaseClient? {
        client
    }

    static func requireSupabase() throws -> SupabaseClient {
        if let client {
            return client
        }

        throw configurationError ?? AppError.invalidConfiguration("SUPABASE_URL")
    }

    static func requireAPIBaseURL() throws -> URL {
        switch configurationResult {
        case let .success(configuration):
            return configuration.apiBaseURL
        case let .failure(error):
            throw error
        }
    }

    private static func loadConfiguration() -> Result<Configuration, AppError> {
        do {
            let supabaseURLString = try requiredInfoValue("SUPABASE_URL")
            let supabaseKey = try requiredInfoValue("SUPABASE_PUBLISHABLE_KEY")
            let apiBaseURLString = try requiredInfoValue("API_BASE_URL")

            guard let supabaseURL = URL(string: supabaseURLString) else {
                throw AppError.invalidConfiguration("SUPABASE_URL")
            }

            guard let apiBaseURL = URL(string: apiBaseURLString) else {
                throw AppError.invalidConfiguration("API_BASE_URL")
            }

            logger.notice("backend configuration loaded")
            return .success(
                Configuration(
                    supabaseURL: supabaseURL,
                    supabaseKey: supabaseKey,
                    apiBaseURL: apiBaseURL
                )
            )
        } catch let error as AppError {
            logger.error("backend configuration failed: \(error.localizedDescription, privacy: .public)")
            return .failure(error)
        } catch {
            logger.error("backend configuration failed: \(error.localizedDescription, privacy: .public)")
            return .failure(.invalidConfiguration("APP_ENVIRONMENT"))
        }
    }

    private static func requiredInfoValue(_ key: String) throws -> String {
        let value = (infoBundle.object(forInfoDictionaryKey: key) as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value, !value.isEmpty else {
            throw AppError.missingConfiguration(key)
        }

        return value
    }
}

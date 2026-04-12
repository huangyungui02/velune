import Foundation
import Security
import UIKit

enum InstallationIDStore {
    private static let account = "velune.installation_id"

    private static var service: String {
        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           !bundleIdentifier.isEmpty {
            return "\(bundleIdentifier).installation"
        }
        return "velune.installation"
    }

    static func getOrCreateInstallationID() -> String {
        if let existing = read(), !existing.isEmpty {
            return existing
        }

        let newValue = UUID().uuidString.lowercased()
        _ = save(newValue)
        return newValue
    }

    private static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    @discardableResult
    private static func save(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }

        guard addStatus == errSecDuplicateItem else {
            return false
        }

        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        return updateStatus == errSecSuccess
    }
}

enum AnonymousRefreshTokenStore {
    private static let account = "velune.anonymous_refresh_token"

    private static var service: String {
        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           !bundleIdentifier.isEmpty {
            return "\(bundleIdentifier).auth"
        }
        return "velune.auth"
    }

    static func read() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        guard status == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }

        return value
    }

    @discardableResult
    static func save(_ value: String) -> Bool {
        guard let data = value.data(using: .utf8) else {
            return false
        }

        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        if addStatus == errSecSuccess {
            return true
        }

        guard addStatus == errSecDuplicateItem else {
            return false
        }

        let updateQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        let updateStatus = SecItemUpdate(updateQuery as CFDictionary, attributes as CFDictionary)
        return updateStatus == errSecSuccess
    }

    static func clear() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        SecItemDelete(query as CFDictionary)
    }
}

struct InstallationClientMetadata {
    let appVersion: String
    let osVersion: String
    let deviceModel: String

    static func current() -> Self {
        Self(
            appVersion: resolvedAppVersion(),
            osVersion: resolvedOSVersion(),
            deviceModel: resolvedDeviceModel()
        )
    }

    private static func resolvedAppVersion() -> String {
        let shortVersion = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let buildNumber = (Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !shortVersion.isEmpty, !buildNumber.isEmpty {
            return "\(shortVersion)+\(buildNumber)"
        }
        if !shortVersion.isEmpty {
            return shortVersion
        }
        if !buildNumber.isEmpty {
            return buildNumber
        }
        return "unknown"
    }

    private static func resolvedOSVersion() -> String {
        let version = UIDevice.current.systemVersion.trimmingCharacters(in: .whitespacesAndNewlines)
        return version.isEmpty ? "unknown" : version
    }

    private static func resolvedDeviceModel() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)

        let identifier = withUnsafeBytes(of: &systemInfo.machine) { rawBuffer -> String in
            let bytes = rawBuffer.prefix { $0 != 0 }
            return String(decoding: bytes, as: UTF8.self)
        }

        return identifier.isEmpty ? "unknown" : identifier
    }
}

enum InstallationVersionSyncStore {
    private static var userIDKey: String {
        "\(keyPrefix).last_synced_user_id"
    }
    private static var appVersionKey: String {
        "\(keyPrefix).last_synced_app_version"
    }
    private static var osVersionKey: String {
        "\(keyPrefix).last_synced_os_version"
    }

    private static var keyPrefix: String {
        if let bundleIdentifier = Bundle.main.bundleIdentifier,
           !bundleIdentifier.isEmpty {
            return "\(bundleIdentifier).installation"
        }
        return "velune.installation"
    }

    static func hasSyncChanged(userId: UUID, appVersion: String, osVersion: String) -> Bool {
        let defaults = UserDefaults.standard
        let userID = userId.uuidString.lowercased()

        guard let lastUserID = defaults.string(forKey: userIDKey),
              let lastAppVersion = defaults.string(forKey: appVersionKey),
              let lastOSVersion = defaults.string(forKey: osVersionKey)
        else {
            return true
        }

        return lastUserID != userID || lastAppVersion != appVersion || lastOSVersion != osVersion
    }

    static func markSynced(userId: UUID, appVersion: String, osVersion: String) {
        let defaults = UserDefaults.standard
        defaults.set(userId.uuidString.lowercased(), forKey: userIDKey)
        defaults.set(appVersion, forKey: appVersionKey)
        defaults.set(osVersion, forKey: osVersionKey)
    }
}

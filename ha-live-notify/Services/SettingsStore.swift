import Foundation
import Security

@Observable
final class SettingsStore {
    static let appGroupID = "group.ios.ha-live-notify"
    private static let baseURLKey = "ha_base_url"
    private static let tokenKey = "ha_access_token"
    private static let service = "ha-live-notify"

    private static var sharedDefaults: UserDefaults {
        UserDefaults(suiteName: appGroupID) ?? .standard
    }

    var config: ServerConfig {
        didSet {
            save()
        }
    }

    var isConfigured: Bool {
        config.isValid
    }

    init() {
        let url = Self.sharedDefaults.string(forKey: Self.baseURLKey) ?? ""
        let token = Self.loadTokenFromKeychain() ?? ""
        self.config = ServerConfig(baseURL: url, accessToken: token)
    }

    private func save() {
        // Only store the base URL in UserDefaults (not sensitive)
        Self.sharedDefaults.set(config.baseURL, forKey: Self.baseURLKey)
        // Token goes to Keychain with App Group sharing
        Self.saveTokenToKeychain(config.accessToken)
    }

    func reset() {
        config = ServerConfig(baseURL: "", accessToken: "")
        Self.sharedDefaults.removeObject(forKey: Self.baseURLKey)
        Self.deleteTokenFromKeychain()
    }

    // MARK: - Keychain (shared via App Group, protected when locked)

    /// Returns true if the token was saved successfully
    @discardableResult
    private static func saveTokenToKeychain(_ token: String) -> Bool {
        let data = Data(token.utf8)

        // Delete any existing item first
        let deleteQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecAttrAccessGroup as String: appGroupID,
        ]
        SecItemDelete(deleteQuery as CFDictionary)

        guard !token.isEmpty else { return true } // Nothing to save

        // Save with protection: accessible only after first device unlock
        let addQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecAttrAccessGroup as String: appGroupID,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    private static func loadTokenFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecAttrAccessGroup as String: appGroupID,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteTokenFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: tokenKey,
            kSecAttrAccessGroup as String: appGroupID,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

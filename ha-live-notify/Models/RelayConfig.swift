import Foundation
import Security

/// Stores Push Relay server configuration.
/// URL is in UserDefaults; API key is in Keychain for security.
enum RelayConfig {
    private static let urlKey = "relay_url"
    private static let keychainService = "ha-live-notify-relay"
    private static let keychainAccount = "relay_api_key"

    static var url: String {
        get { UserDefaults.standard.string(forKey: urlKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: urlKey) }
    }

    static var apiKey: String {
        get { loadKeyFromKeychain() ?? "" }
        set { saveKeyToKeychain(newValue) }
    }

    static var isConfigured: Bool {
        !url.isEmpty && !apiKey.isEmpty
    }

    static var baseURL: URL? {
        URL(string: url)
    }

    /// #3: Validate relay URL - warn when using HTTP for non-private IPs.
    /// Returns nil if URL is safe, or a warning string if insecure.
    static func validateURL(_ urlString: String) -> String? {
        guard let parsed = URL(string: urlString),
              let host = parsed.host?.lowercased(),
              let scheme = parsed.scheme?.lowercased() else {
            return "Ungültige URL"
        }

        // HTTPS is always fine
        if scheme == "https" { return nil }

        // HTTP is only acceptable for private/local networks
        if scheme == "http" {
            if isPrivateHost(host) { return nil }
            return "Warnung: HTTP ist unsicher für öffentliche Adressen. Bitte HTTPS verwenden."
        }

        return nil
    }

    /// Check if a host is on a private/local network.
    private static func isPrivateHost(_ host: String) -> Bool {
        if host == "localhost" || host == "127.0.0.1" || host == "::1" { return true }
        if host.hasSuffix(".local") || host.hasSuffix(".home")
            || host.hasSuffix(".internal") || host.hasSuffix(".lan") { return true }

        // Check RFC 1918 private IP ranges
        let parts = host.split(separator: ".").compactMap { UInt8($0) }
        guard parts.count == 4 else { return false }
        if parts[0] == 10 { return true }
        if parts[0] == 172 && (16...31).contains(parts[1]) { return true }
        if parts[0] == 192 && parts[1] == 168 { return true }
        if parts[0] == 169 && parts[1] == 254 { return true }
        return false
    }

    static func reset() {
        url = ""
        deleteKeyFromKeychain()
    }

    // MARK: - Keychain

    private static func saveKeyToKeychain(_ key: String) {
        deleteKeyFromKeychain()
        guard !key.isEmpty else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecValueData as String: Data(key.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadKeyFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteKeyFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }
}

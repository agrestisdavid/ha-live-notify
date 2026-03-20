import ActivityKit
import Foundation
import Security

/// Manages ActivityKit push tokens and registers them with the push relay server.
actor PushTokenManager {
    static let shared = PushTokenManager()

    private var registeredTokens: [String: String] = [:]  // entityID -> pushToken
    private var lastPushToStartToken: String?  // Cache last known push-to-start token
    private let deviceID: String

    // #4: Dedicated URLSession with TLS 1.2 minimum, no cache, no cookies
    private let relaySession: URLSession = {
        let config = URLSessionConfiguration.default
        config.urlCache = nil
        config.httpCookieStorage = nil
        config.httpShouldSetCookies = false
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 60
        config.tlsMinimumSupportedProtocolVersion = .TLSv12
        return URLSession(configuration: config)
    }()

    // #8: Keychain constants for device_id
    private static let keychainService = "ha-live-notify"
    private static let keychainDeviceIDAccount = "device_id"

    private init() {
        // #8: Load device_id from Keychain instead of UserDefaults
        if let existing = PushTokenManager.loadDeviceIDFromKeychain() {
            deviceID = existing
        } else {
            // Migrate from UserDefaults if present
            if let legacy = UserDefaults.standard.string(forKey: "device_id") {
                deviceID = legacy
                PushTokenManager.saveDeviceIDToKeychain(legacy)
                UserDefaults.standard.removeObject(forKey: "device_id")
            } else {
                let id = UUID().uuidString
                PushTokenManager.saveDeviceIDToKeychain(id)
                deviceID = id
            }
        }
    }

    // MARK: - Keychain helpers for device_id (#8)

    private static func saveDeviceIDToKeychain(_ id: String) {
        deleteDeviceIDFromKeychain()
        guard !id.isEmpty else { return }
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainDeviceIDAccount,
            kSecValueData as String: Data(id.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func loadDeviceIDFromKeychain() -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainDeviceIDAccount,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func deleteDeviceIDFromKeychain() {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: keychainService,
            kSecAttrAccount as String: keychainDeviceIDAccount,
        ]
        SecItemDelete(query as CFDictionary)
    }

    // MARK: - Push-to-Start Token (registers on app launch)

    /// Register the push-to-start token so the relay can START activities even when app is closed.
    func registerPushToStartToken() async {
        guard RelayConfig.isConfigured else {
            #if DEBUG
            print("[PushToken] Relay not configured, skipping push-to-start registration")
            #endif
            return
        }

        #if DEBUG
        print("[PushToken] Starting push-to-start token listener...")
        print("[PushToken] Relay URL: \(RelayConfig.url)")
        print("[PushToken] Relay configured: \(RelayConfig.isConfigured)")
        print("[PushToken] API key present: \(!RelayConfig.apiKey.isEmpty)")
        #endif

        // Check if Live Activities are enabled
        let authInfo = ActivityAuthorizationInfo()
        #if DEBUG
        print("[PushToken] Live Activities enabled: \(authInfo.areActivitiesEnabled)")
        print("[PushToken] Frequent push enabled: \(authInfo.frequentPushesEnabled)")
        #endif

        // Listen for push-to-start token updates
        for await tokenData in Activity<TimerActivityAttributes>.pushToStartTokenUpdates {
            let token = tokenData.map { String(format: "%02x", $0) }.joined()
            lastPushToStartToken = token
            #if DEBUG
            print("[PushToken] Got push-to-start token: \(token.prefix(16))...")
            #endif

            // Get selected entity IDs
            let entityIDs = EntitySelection.selectedIDs()
            #if DEBUG
            print("[PushToken] Selected entities: \(entityIDs)")
            #endif
            guard !entityIDs.isEmpty else {
                #if DEBUG
                print("[PushToken] No entities selected, skipping registration")
                #endif
                continue
            }

            await sendRegistration(pushToken: token, entityIDs: Array(entityIDs))
        }
        #if DEBUG
        print("[PushToken] push-to-start token stream ended")
        #endif
    }

    /// Re-register with the relay using the last known token.
    /// Call this on app foreground / when entity selection changes.
    func reRegisterIfNeeded() async {
        guard RelayConfig.isConfigured else { return }

        guard let token = lastPushToStartToken else {
            #if DEBUG
            print("[PushToken] No cached token yet, waiting for pushToStartTokenUpdates")
            #endif
            return
        }

        let entityIDs = EntitySelection.selectedIDs()
        guard !entityIDs.isEmpty else { return }

        await sendRegistration(pushToken: token, entityIDs: Array(entityIDs))
    }

    // MARK: - Per-Activity Push Token (for updates to existing activities)

    /// Register push token for an active Live Activity.
    func registerActivityToken(_ token: String, for entityID: String) async {
        if registeredTokens[entityID] == token { return }
        registeredTokens[entityID] = token

        await sendRegistration(pushToken: token, entityIDs: [entityID])
    }

    /// Remove token when activity ends.
    func unregisterEntity(_ entityID: String) {
        registeredTokens.removeValue(forKey: entityID)
    }

    // MARK: - Network

    private func sendRegistration(pushToken: String, entityIDs: [String]) async {
        guard let baseURL = RelayConfig.baseURL else {
            #if DEBUG
            print("[PushToken] Invalid relay URL")
            #endif
            return
        }

        let url = baseURL.appendingPathComponent("register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(RelayConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        // Include entity configs so relay knows icon/color/invertProgress
        var entityConfigs: [[String: Any]] = []
        for entityID in entityIDs {
            let config = EntityConfigStore.config(for: entityID)
            entityConfigs.append([
                "entity_id": entityID,
                "icon_name": config.iconName,
                "color_hex": config.colorHex,
                "invert_progress": config.invertProgress,
            ])
        }

        let body: [String: Any] = [
            "device_id": deviceID,
            "push_token": pushToken,
            "entity_ids": entityIDs,
            "entity_configs": entityConfigs,
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            // #4: Use dedicated session instead of URLSession.shared
            let (_, response) = try await relaySession.data(for: request)
            if let http = response as? HTTPURLResponse {
                if http.statusCode == 200 {
                    #if DEBUG
                    print("[PushToken] Registered for entities: \(entityIDs)")
                    #endif
                } else {
                    #if DEBUG
                    print("[PushToken] Registration failed: HTTP \(http.statusCode)")
                    #endif
                }
            }
        } catch {
            #if DEBUG
            print("[PushToken] Registration error: \(error.localizedDescription)")
            #endif
        }
    }
}

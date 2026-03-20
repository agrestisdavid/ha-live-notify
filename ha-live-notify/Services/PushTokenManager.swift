import ActivityKit
import Foundation
import Security

actor PushTokenManager {
    static let shared = PushTokenManager()

    private var registeredTokens: [String: String] = [:]
    private var lastPushToStartToken: String?
    private let deviceID: String

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

    private static let keychainService = "ha-live-notify"
    private static let keychainDeviceIDAccount = "device_id"

    private init() {
        if let existing = PushTokenManager.loadDeviceIDFromKeychain() {
            deviceID = existing
        } else {
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

    func registerPushToStartToken() async {
        guard RelayConfig.isConfigured else {
            return
        }

        let authInfo = ActivityAuthorizationInfo()
        _ = authInfo.areActivitiesEnabled

        for await tokenData in Activity<TimerActivityAttributes>.pushToStartTokenUpdates {
            let token = tokenData.map { String(format: "%02x", $0) }.joined()
            lastPushToStartToken = token

            let entityIDs = EntitySelection.selectedIDs()
            guard !entityIDs.isEmpty else {
                continue
            }

            await sendRegistration(pushToken: token, entityIDs: Array(entityIDs))
        }
    }

    func reRegisterIfNeeded() async {
        guard RelayConfig.isConfigured else { return }

        guard let token = lastPushToStartToken else {
            return
        }

        let entityIDs = EntitySelection.selectedIDs()
        guard !entityIDs.isEmpty else { return }

        await sendRegistration(pushToken: token, entityIDs: Array(entityIDs))
    }

    func registerActivityToken(_ token: String, for entityID: String) async {
        if registeredTokens[entityID] == token { return }
        registeredTokens[entityID] = token

        await sendRegistration(pushToken: token, entityIDs: [entityID])
    }

    func unregisterEntity(_ entityID: String) {
        registeredTokens.removeValue(forKey: entityID)
    }

    private func sendRegistration(pushToken: String, entityIDs: [String]) async {
        guard let baseURL = RelayConfig.baseURL else {
            return
        }

        let url = baseURL.appendingPathComponent("register")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(RelayConfig.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

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
            let (_, response) = try await relaySession.data(for: request)
            _ = response as? HTTPURLResponse
        } catch {
        }
    }
}

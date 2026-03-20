import Foundation
import UIKit

@Observable
final class HAWebSocketService {
    enum ConnectionState: Equatable {
        case disconnected
        case connecting
        case authenticating
        case connected
        case error(String)
    }

    private(set) var connectionState: ConnectionState = .disconnected
    private(set) var entities: [HAEntity] = []

    var allTimerEntities: [HAEntity] {
        entities.filter { $0.isTimer }
    }

    var selectedTimerEntities: [HAEntity] {
        let selected = EntitySelection.selectedIDs()
        return entities.filter { $0.isTimer && selected.contains($0.entityID) }
    }

    private var webSocket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var config: ServerConfig?
    private var messageID: Int = 0
    private var pendingHandlers: [Int: (Result<HAWebSocketResponse, Error>) -> Void] = [:]
    private var stateSubscriptionID: Int?

    private var reconnectAttempt: Int = 0
    private var reconnectTask: Task<Void, Never>?
    private var shouldReconnect = false
    private var pingTask: Task<Void, Never>?
    private var backgroundTaskID: UIBackgroundTaskIdentifier = .invalid

    var onEntityStateChanged: ((HAEntity) -> Void)?

    func connect(config: ServerConfig) {
        guard let url = config.websocketURL else {
            connectionState = .error("Ungültige URL")
            return
        }

        self.config = config
        self.shouldReconnect = true
        self.reconnectAttempt = 0
        connectionState = .connecting

        let sessionConfig = URLSessionConfiguration.default
        sessionConfig.urlCache = nil
        sessionConfig.httpCookieStorage = nil
        sessionConfig.httpShouldSetCookies = false
        sessionConfig.timeoutIntervalForRequest = 30
        sessionConfig.timeoutIntervalForResource = 300
        sessionConfig.tlsMinimumSupportedProtocolVersion = .TLSv12

        session = URLSession(configuration: sessionConfig)
        webSocket = session?.webSocketTask(with: url)
        webSocket?.maximumMessageSize = 1_048_576
        webSocket?.resume()
        receiveMessage()
        startPingTimer()
    }

    func disconnect() {
        shouldReconnect = false
        reconnectTask?.cancel()
        reconnectTask = nil
        pingTask?.cancel()
        pingTask = nil
        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        session?.invalidateAndCancel()
        session = nil
        connectionState = .disconnected
        config = nil
        entities = []
        pendingHandlers.removeAll()
        stateSubscriptionID = nil
        messageID = 0
        endBackgroundTask()
    }

    func handleAppDidEnterBackground() {
        guard connectionState == .connected else { return }

        backgroundTaskID = UIApplication.shared.beginBackgroundTask { [weak self] in
            self?.endBackgroundTask()
        }
    }

    func handleAppDidBecomeActive() {
        endBackgroundTask()

        if shouldReconnect, connectionState != .connected, connectionState != .connecting {
            guard let config else { return }
            reconnectAttempt = 0
            connect(config: config)
        }
    }

    private func endBackgroundTask() {
        guard backgroundTaskID != .invalid else { return }
        UIApplication.shared.endBackgroundTask(backgroundTaskID)
        backgroundTaskID = .invalid
    }

    private func startPingTimer() {
        pingTask?.cancel()
        pingTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard let self, !Task.isCancelled else { return }
                self.webSocket?.sendPing { [weak self] error in
                    if error != nil {
                        Task { @MainActor in
                            self?.scheduleReconnect()
                        }
                    }
                }
            }
        }
    }

    private func scheduleReconnect() {
        guard shouldReconnect else { return }

        webSocket?.cancel(with: .goingAway, reason: nil)
        webSocket = nil
        pingTask?.cancel()

        reconnectAttempt += 1
        let baseDelay = min(pow(2.0, Double(reconnectAttempt)), 60.0)
        let jitter = baseDelay * Double.random(in: 0...0.25)
        let delay = baseDelay + jitter
        connectionState = .error("Verbindung verloren. Neuversuch in \(Int(delay))s...")

        reconnectTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard let self, self.shouldReconnect, !Task.isCancelled else { return }
            guard let config = self.config else { return }
            await MainActor.run {
                self.connect(config: config)
            }
        }
    }

    private func receiveMessage() {
        webSocket?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    self.handleMessage(text)
                default:
                    break
                }
                self.receiveMessage()

            case .failure:
                Task { @MainActor in
                    self.scheduleReconnect()
                }
            }
        }
    }

    private func handleMessage(_ text: String) {
        guard let data = text.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = json["type"] as? String
        else { return }

        Task { @MainActor in
            switch type {
            case "auth_required":
                self.connectionState = .authenticating
                self.sendAuth()

            case "auth_ok":
                self.connectionState = .connected
                self.reconnectAttempt = 0
                self.fetchStates()
                self.subscribeToStateChanges()

            case "auth_invalid":
                self.shouldReconnect = false
                self.connectionState = .error("Ungültiger Access Token")
                self.config = nil

            case "result":
                self.handleResult(json)

            case "event":
                self.handleEvent(json)

            default:
                break
            }
        }
    }

    private func sendAuth() {
        guard let token = config?.accessToken, !token.isEmpty else { return }

        guard let expectedHost = config?.websocketURL?.host?.lowercased(),
              let actualHost = webSocket?.currentRequest?.url?.host?.lowercased(),
              expectedHost == actualHost
        else {
            shouldReconnect = false
            connectionState = .error("Sicherheitsfehler: Server-Host stimmt nicht überein")
            webSocket?.cancel(with: .goingAway, reason: nil)
            return
        }

        let msg = ["type": "auth", "access_token": token]
        sendJSON(msg)
    }

    func refresh() {
        guard connectionState == .connected else { return }
        fetchStates()
    }

    private func fetchStates() {
        let id = nextID()
        let msg: [String: Any] = ["id": id, "type": "get_states"]

        pendingHandlers[id] = { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let response):
                if let entities = response.entities {
                    Task { @MainActor in
                        self.entities = entities
                    }
                }
            case .failure:
                break
            }
        }

        sendJSON(msg)
    }

    private func subscribeToStateChanges() {
        let id = nextID()
        stateSubscriptionID = id

        let msg: [String: Any] = [
            "id": id,
            "type": "subscribe_events",
            "event_type": "state_changed",
        ]

        sendJSON(msg)
    }

    private func handleResult(_ json: [String: Any]) {
        guard let id = json["id"] as? Int else { return }

        if let handler = pendingHandlers.removeValue(forKey: id) {
            let success = json["success"] as? Bool ?? false
            if success {
                let rawResult = json["result"]
                if let resultArray = json["result"] as? [[String: Any]] {
                    let entities = parseEntities(resultArray)
                    handler(.success(HAWebSocketResponse(entities: entities, rawResult: rawResult)))
                } else {
                    handler(.success(HAWebSocketResponse(entities: nil, rawResult: rawResult)))
                }
            } else {
                let msg = (json["error"] as? [String: Any])?["message"] as? String ?? "Unknown error"
                handler(.failure(HAError.apiError(msg)))
            }
        }
    }

    private static let maxEntities = 10_000

    private func handleEvent(_ json: [String: Any]) {
        guard let event = json["event"] as? [String: Any],
              let eventData = event["data"] as? [String: Any],
              let newState = eventData["new_state"] as? [String: Any],
              let entity = parseEntity(newState)
        else { return }

        if let idx = entities.firstIndex(where: { $0.entityID == entity.entityID }) {
            entities[idx] = entity
        } else {
            guard entities.count < Self.maxEntities else { return }
            entities.append(entity)
        }

        onEntityStateChanged?(entity)
    }

    private func parseEntities(_ array: [[String: Any]]) -> [HAEntity] {
        array.compactMap { parseEntity($0) }
    }

    private func parseEntity(_ dict: [String: Any]) -> HAEntity? {
        guard let entityID = dict["entity_id"] as? String,
              let state = dict["state"] as? String
        else { return nil }

        let attrs = dict["attributes"] as? [String: Any] ?? [:]

        let attributes = HAEntityAttributes(
            friendlyName: attrs["friendly_name"] as? String,
            icon: attrs["icon"] as? String,
            deviceClass: attrs["device_class"] as? String,
            duration: attrs["duration"] as? String,
            finishesAt: attrs["finishes_at"] as? String
        )

        return HAEntity(
            entityID: entityID,
            state: state,
            attributes: attributes
        )
    }

    private func nextID() -> Int {
        messageID += 1
        return messageID
    }

    private func sendJSON(_ dict: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: dict),
              let text = String(data: data, encoding: .utf8)
        else { return }

        webSocket?.send(.string(text)) { [weak self] error in
            if error != nil {
                Task { @MainActor in
                    self?.scheduleReconnect()
                }
            }
        }
    }
}

struct HAWebSocketResponse {
    let entities: [HAEntity]?
    let rawResult: Any?
}

enum HAError: LocalizedError {
    case apiError(String)

    var errorDescription: String? {
        switch self {
        case .apiError(let msg): return msg
        }
    }
}

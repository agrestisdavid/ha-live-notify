import Foundation

struct HAEntity: Identifiable, Codable, Hashable {
    let entityID: String
    let state: String
    let attributes: HAEntityAttributes

    var id: String { entityID }

    var friendlyName: String {
        attributes.friendlyName ?? entityID
    }

    var iconName: String {
        mapIcon(attributes.icon)
    }

    var isTimer: Bool {
        entityID.hasPrefix("timer.") ||
        (entityID.hasPrefix("sensor.") && attributes.deviceClass == "duration")
    }

    /// Parses the HA timer's `finishes_at` or calculates from `duration` + `last_changed`
    var finishesAt: Date? {
        if let finishesAt = attributes.finishesAt {
            return ISO8601DateFormatter().date(from: finishesAt)
        }
        return nil
    }

    var duration: TimeInterval? {
        guard let durationStr = attributes.duration else { return nil }
        let parts = durationStr.split(separator: ":").compactMap { Double($0) }
        guard parts.count == 3 else { return nil }
        return parts[0] * 3600 + parts[1] * 60 + parts[2]
    }

    private func mapIcon(_ haIcon: String?) -> String {
        guard let haIcon else { return "timer" }
        let name = haIcon.replacingOccurrences(of: "mdi:", with: "")
        let mapping: [String: String] = [
            "washing-machine": "washer.fill",
            "dishwasher": "dishwasher.fill",
            "tumble-dryer": "dryer.fill",
            "robot-vacuum": "fan.floor.fill",
            "timer": "timer",
            "timer-sand": "hourglass",
            "oven": "oven.fill",
            "microwave": "microwave.fill",
        ]
        return mapping[name] ?? "timer"
    }
}

struct HAEntityAttributes: Codable, Hashable {
    let friendlyName: String?
    let icon: String?
    let deviceClass: String?
    let duration: String?
    let finishesAt: String?

    enum CodingKeys: String, CodingKey {
        case friendlyName = "friendly_name"
        case icon
        case deviceClass = "device_class"
        case duration
        case finishesAt = "finishes_at"
    }
}

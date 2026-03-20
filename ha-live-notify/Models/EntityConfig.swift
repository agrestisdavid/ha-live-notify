import Foundation
import SwiftUI

/// Per-entity customization (icon, color) persisted in App Group UserDefaults
struct EntityConfig: Codable, Equatable {
    var iconName: String
    var colorHex: String
    var invertProgress: Bool = false

    var color: Color {
        Color(hex: colorHex) ?? .orange
    }

    static let `default` = EntityConfig(iconName: "timer", colorHex: "#FF9500")

    static let availableIcons = [
        "timer", "hourglass", "washer.fill", "dishwasher.fill",
        "dryer.fill", "oven.fill", "microwave.fill", "fan.floor.fill",
        "cup.and.heat.waves.fill", "fork.knife", "bed.double.fill",
        "shower.fill", "bolt.fill", "leaf.fill",
    ]

    static let availableColors: [(name: String, hex: String)] = [
        ("Orange", "#FF9500"),
        ("Blau", "#007AFF"),
        ("Grün", "#34C759"),
        ("Rot", "#FF3B30"),
        ("Lila", "#AF52DE"),
        ("Pink", "#FF2D55"),
        ("Türkis", "#5AC8FA"),
        ("Gelb", "#FFCC00"),
    ]
}

/// Manages per-entity configuration stored in App Group UserDefaults
final class EntityConfigStore {
    private static let key = "entity_configs"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SettingsStore.appGroupID) ?? .standard
    }

    static func config(for entityID: String) -> EntityConfig {
        let all = loadAll()
        return all[entityID] ?? .default
    }

    static func setConfig(_ config: EntityConfig, for entityID: String) {
        var all = loadAll()
        all[entityID] = config
        saveAll(all)
    }

    private static func loadAll() -> [String: EntityConfig] {
        guard let data = defaults.data(forKey: key),
              let configs = try? JSONDecoder().decode([String: EntityConfig].self, from: data)
        else { return [:] }
        return configs
    }

    private static func saveAll(_ configs: [String: EntityConfig]) {
        guard let data = try? JSONEncoder().encode(configs) else { return }
        defaults.set(data, forKey: key)
    }
}

// MARK: - Color hex extension

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6,
              let int = UInt64(h, radix: 16)
        else { return nil }

        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}

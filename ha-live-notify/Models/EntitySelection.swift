import Foundation

/// Stores which entity IDs the user has selected for Live Activity tracking.
/// Persisted in App Group UserDefaults so the widget can also access it.
final class EntitySelection {
    private static let key = "selected_entity_ids"
    private static var defaults: UserDefaults {
        UserDefaults(suiteName: SettingsStore.appGroupID) ?? .standard
    }

    static func selectedIDs() -> Set<String> {
        let array = defaults.stringArray(forKey: key) ?? []
        return Set(array)
    }

    static func isSelected(_ entityID: String) -> Bool {
        selectedIDs().contains(entityID)
    }

    static func setSelected(_ entityID: String, selected: Bool) {
        var ids = selectedIDs()
        if selected {
            ids.insert(entityID)
        } else {
            ids.remove(entityID)
        }
        defaults.set(Array(ids), forKey: key)

        // Re-register with relay so it knows the updated entity list
        Task {
            await PushTokenManager.shared.reRegisterIfNeeded()
        }
    }
}

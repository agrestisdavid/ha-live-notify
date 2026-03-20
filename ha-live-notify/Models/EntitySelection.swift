import Foundation

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

        Task {
            await PushTokenManager.shared.reRegisterIfNeeded()
        }
    }
}

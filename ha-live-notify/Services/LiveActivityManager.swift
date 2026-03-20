import ActivityKit
import Foundation

@Observable
final class LiveActivityManager {
    private(set) var activeActivities: [Activity<TimerActivityAttributes>] = []

    init() {
        refreshActivities()
    }

    func refreshActivities() {
        activeActivities = Activity<TimerActivityAttributes>.activities.filter {
            $0.activityState == .active || $0.activityState == .stale
        }
    }

    func isTracking(entityID: String) -> Bool {
        // Check all system activities (includes push-to-start ones not in our array)
        Activity<TimerActivityAttributes>.activities.contains {
            $0.attributes.entityID == entityID
            && ($0.activityState == .active || $0.activityState == .stale)
        }
    }

    func startActivity(for entity: HAEntity) throws {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            throw LiveActivityError.notEnabled
        }

        guard entity.state == "active" else {
            throw LiveActivityError.entityNotActive
        }

        guard let finishesAt = entity.finishesAt else {
            throw LiveActivityError.noEndTime
        }

        // Don't duplicate: check both our tracked list AND all system activities
        // (push-to-start can create activities we don't track in our array yet)
        let allSystemActivities = Activity<TimerActivityAttributes>.activities
        if allSystemActivities.contains(where: {
            $0.attributes.entityID == entity.entityID
            && ($0.activityState == .active || $0.activityState == .stale)
        }) {
            throw LiveActivityError.alreadyTracking
        }

        let config = EntityConfigStore.config(for: entity.entityID)
        let attributes = TimerActivityAttributes(
            entityID: entity.entityID,
            deviceName: entity.friendlyName,
            iconName: config.iconName,
            accentColorHex: config.colorHex,
            invertProgress: config.invertProgress
        )

        let state = TimerActivityAttributes.ContentState(
            endTime: finishesAt,
            state: .active,
            totalDuration: entity.duration ?? finishesAt.timeIntervalSinceNow,
            progress: nil
        )

        let content = ActivityContent(state: state, staleDate: finishesAt.addingTimeInterval(60))

        let activity = try Activity.request(
            attributes: attributes,
            content: content,
            pushType: .token
        )

        activeActivities.append(activity)

        // Register push token for background updates
        Task {
            for await tokenData in activity.pushTokenUpdates {
                let token = tokenData.map { String(format: "%02x", $0) }.joined()
                await PushTokenManager.shared.registerActivityToken(
                    token,
                    for: entity.entityID
                )
            }
        }
    }

    func updateActivity(for entityID: String, newState: HAEntity) {
        // Also pick up push-started activities not yet in our local array
        refreshActivities()

        guard let activity = activeActivities.first(where: { $0.attributes.entityID == entityID })
        else { return }

        let timerState: TimerActivityAttributes.ContentState.TimerState
        let endTime: Date
        let totalDuration = activity.content.state.totalDuration
        var progress: Double?

        switch newState.state {
        case "active":
            timerState = .active
            endTime = newState.finishesAt ?? Date().addingTimeInterval(60)
            progress = nil

        case "paused":
            timerState = .paused
            endTime = activity.content.state.endTime
            if totalDuration > 0 {
                let remaining = activity.content.state.endTime.timeIntervalSince(Date())
                progress = max(0, min(1, 1.0 - remaining / totalDuration))
            }

        case "idle":
            timerState = .finished
            endTime = Date()
            progress = 1.0

        default:
            timerState = .finished
            endTime = Date()
            progress = 1.0
        }

        let state = TimerActivityAttributes.ContentState(
            endTime: endTime,
            state: timerState,
            totalDuration: totalDuration,
            progress: progress
        )

        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.update(content)

            if timerState == .finished {
                try? await Task.sleep(for: .seconds(5))
                await activity.end(content, dismissalPolicy: .default)
                await MainActor.run { refreshActivities() }
            }
        }
    }

    func endActivity(_ activity: Activity<TimerActivityAttributes>) {
        let state = TimerActivityAttributes.ContentState(
            endTime: Date(),
            state: .finished,
            totalDuration: activity.content.state.totalDuration,
            progress: 1.0
        )
        let content = ActivityContent(state: state, staleDate: nil)

        Task {
            await activity.end(content, dismissalPolicy: .immediate)
            await MainActor.run { refreshActivities() }
        }
    }
}

enum LiveActivityError: LocalizedError {
    case notEnabled
    case entityNotActive
    case noEndTime
    case alreadyTracking

    var errorDescription: String? {
        switch self {
        case .notEnabled:
            return "Live Activities sind in den Einstellungen deaktiviert."
        case .entityNotActive:
            return "Der Timer läuft nicht."
        case .noEndTime:
            return "Kein Endzeitpunkt für diesen Timer gefunden."
        case .alreadyTracking:
            return "Dieser Timer wird bereits als Live Activity angezeigt."
        }
    }
}

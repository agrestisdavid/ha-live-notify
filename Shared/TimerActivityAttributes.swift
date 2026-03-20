import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    let entityID: String
    let deviceName: String
    let iconName: String
    let accentColorHex: String
    let invertProgress: Bool

    struct ContentState: Codable, Hashable {
        let endTime: Date
        let state: TimerState
        let totalDuration: TimeInterval
        let progress: Double?

        enum TimerState: String, Codable, Hashable {
            case active
            case paused
            case idle
            case finished
        }
    }
}

import ActivityKit
import Foundation

struct TimerActivityAttributes: ActivityAttributes {
    /// Fixed data that doesn't change during the activity
    let entityID: String
    let deviceName: String
    let iconName: String
    let accentColorHex: String // hex color e.g. "#FF6B00"
    let invertProgress: Bool

    /// Dynamic data that updates in real-time
    struct ContentState: Codable, Hashable {
        let endTime: Date
        let state: TimerState
        /// Total timer duration in seconds (for correct progress calculation)
        let totalDuration: TimeInterval
        /// Progress value (0.0 - 1.0) snapshot, used when paused to freeze the bar
        let progress: Double?

        enum TimerState: String, Codable, Hashable {
            case active
            case paused
            case idle
            case finished
        }
    }
}

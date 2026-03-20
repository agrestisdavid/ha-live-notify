import SwiftUI
import UserNotifications

@main
struct ha_live_notifyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    let center = UNUserNotificationCenter.current()
                    try? await center.requestAuthorization(options: [.alert, .sound, .badge])
                    await PushTokenManager.shared.registerPushToStartToken()
                }
        }
    }
}

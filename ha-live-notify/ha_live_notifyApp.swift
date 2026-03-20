//
//  ha_live_notifyApp.swift
//  ha-live-notify
//
//  Created by David Jovanovic on 19.03.26.
//

import SwiftUI
import UserNotifications

@main
struct ha_live_notifyApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    // Request notification permission first
                    let center = UNUserNotificationCenter.current()
                    do {
                        let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
                        #if DEBUG
                        print("[App] Notification permission: \(granted)")
                        #endif
                    } catch {
                        #if DEBUG
                        print("[App] Notification permission error: \(error)")
                        #endif
                    }

                    // Then register push-to-start token
                    await PushTokenManager.shared.registerPushToStartToken()
                }
        }
    }
}

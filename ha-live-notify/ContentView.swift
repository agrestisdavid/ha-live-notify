import SwiftUI

struct ContentView: View {
    @State var settings = SettingsStore()
    @State var websocket = HAWebSocketService()
    @State var activityManager = LiveActivityManager()
    @State private var showSettings = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if settings.isConfigured {
                mainContent
            } else {
                onboardingView
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
        .alert("Fehler", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let errorMessage {
                Text(errorMessage)
            }
        }
        .onChange(of: settings.config) {
            if settings.isConfigured {
                websocket.disconnect()
                websocket.connect(config: settings.config)
            }
        }
        .onAppear {
            setupEntityChangeHandler()
            if settings.isConfigured {
                websocket.connect(config: settings.config)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
            websocket.handleAppDidEnterBackground()
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            websocket.handleAppDidBecomeActive()
            websocket.refresh()
            Task {
                await PushTokenManager.shared.reRegisterIfNeeded()
            }
        }
    }

    private var mainContent: some View {
        TabView {
            Tab("Aktiv", systemImage: "bell.badge") {
                NavigationStack {
                    ActiveActivitiesView(
                        activities: activityManager.activeActivities,
                        onEnd: { activityManager.endActivity($0) }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            connectionStatusButton
                        }
                    }
                }
            }

            Tab("Timer", systemImage: "timer") {
                NavigationStack {
                    EntityBrowserView(
                        entities: websocket.selectedTimerEntities,
                        onStartTimer: startLiveActivity,
                        onRefresh: { websocket.refresh() }
                    )
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            connectionStatusButton
                        }
                    }
                }
            }

            Tab("Einstellungen", systemImage: "gear") {
                NavigationStack {
                    SettingsTabView(
                        settings: settings,
                        allTimerEntities: websocket.allTimerEntities,
                        onReconnect: {
                            websocket.disconnect()
                            websocket.connect(config: settings.config)
                        }
                    )
                }
            }
        }
    }

    private var onboardingView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "bell.badge.circle.fill")
                .font(.system(size: 80))
                .foregroundStyle(.orange)

            Text("HA Live Notify")
                .font(.largeTitle.bold())

            Text("Live Activities für Home Assistant.\nVerbinde dich mit deiner HA-Instanz um loszulegen.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)

            Button {
                showSettings = true
            } label: {
                Label("Verbinden", systemImage: "link")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.orange)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var connectionStatusButton: some View {
        Menu {
            switch websocket.connectionState {
            case .connected:
                if settings.config.isSecureConnection {
                    Label("Verbunden (verschlüsselt)", systemImage: "lock.fill")
                } else {
                    Label("Verbunden (unverschlüsselt)", systemImage: "lock.open.fill")
                    Label("Nur im lokalen Netzwerk sicher", systemImage: "exclamationmark.triangle")
                }
            case .connecting, .authenticating:
                Label("Verbinde...", systemImage: "arrow.trianglehead.2.clockwise")
            case .error(let msg):
                Label(msg, systemImage: "exclamationmark.triangle")
            case .disconnected:
                Label("Getrennt", systemImage: "xmark.circle")
            }

            Divider()

            Button {
                showSettings = true
            } label: {
                Label("Verbindung ändern", systemImage: "link")
            }

            if websocket.connectionState != .connected && settings.isConfigured {
                Button {
                    websocket.connect(config: settings.config)
                } label: {
                    Label("Neu verbinden", systemImage: "arrow.clockwise")
                }
            }
        } label: {
            Image(systemName: connectionIcon)
                .foregroundStyle(connectionColor)
        }
    }

    private var connectionIcon: String {
        switch websocket.connectionState {
        case .connected: "circle.fill"
        case .connecting, .authenticating: "circle.dotted"
        case .error: "exclamationmark.circle.fill"
        case .disconnected: "circle"
        }
    }

    private var connectionColor: Color {
        switch websocket.connectionState {
        case .connected: .green
        case .connecting, .authenticating: .orange
        case .error: .red
        case .disconnected: .secondary
        }
    }

    private func startLiveActivity(_ entity: HAEntity) {
        do {
            try activityManager.startActivity(for: entity)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func setupEntityChangeHandler() {
        websocket.onEntityStateChanged = { entity in
            activityManager.updateActivity(for: entity.entityID, newState: entity)

            if entity.isTimer
                && entity.state == "active"
                && EntitySelection.isSelected(entity.entityID)
                && !activityManager.isTracking(entityID: entity.entityID)
                && !RelayConfig.isConfigured
            {
                try? activityManager.startActivity(for: entity)
            }
        }
    }
}

#Preview {
    ContentView()
}

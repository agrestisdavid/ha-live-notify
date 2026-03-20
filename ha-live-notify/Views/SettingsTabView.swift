import SwiftUI

struct SettingsTabView: View {
    @Bindable var settings: SettingsStore
    let allTimerEntities: [HAEntity]
    var onReconnect: () -> Void
    @State private var selectedCount = 0

    var body: some View {
        List {
            Section {
                NavigationLink {
                    EntitySelectionView(allTimerEntities: allTimerEntities)
                } label: {
                    HStack {
                        Label("Entities", systemImage: "list.bullet")
                        Spacer()
                        Text("\(selectedCount) ausgewählt")
                            .foregroundStyle(.secondary)
                    }
                }
            } header: {
                Text("Live Activities")
            } footer: {
                Text("Wähle aus, welche Timer als Live Activities angezeigt werden.")
            }

            Section {
                HStack {
                    Text("URL")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(settings.config.baseURL)
                        .lineLimit(1)
                }

                HStack {
                    Text("Token")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("••••••••")
                }

                HStack {
                    Text("Verbindung")
                        .foregroundStyle(.secondary)
                    Spacer()
                    if settings.config.isSecureConnection {
                        Label("Verschlüsselt", systemImage: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Unverschlüsselt", systemImage: "lock.open.fill")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }
            } header: {
                Text("Home Assistant")
            }

            Section {
                NavigationLink {
                    RelaySettingsView()
                } label: {
                    HStack {
                        Label("Push Relay", systemImage: "antenna.radiowaves.left.and.right")
                        Spacer()
                        if RelayConfig.isConfigured {
                            Text("Verbunden")
                                .foregroundStyle(.green)
                                .font(.caption)
                        } else {
                            Text("Nicht konfiguriert")
                                .foregroundStyle(.secondary)
                                .font(.caption)
                        }
                    }
                }
            } header: {
                Text("Push-Benachrichtigungen")
            } footer: {
                Text("Ermöglicht Live Activities auch wenn die App geschlossen ist.")
            }

            Section {
                Button {
                    onReconnect()
                } label: {
                    Label("Neu verbinden", systemImage: "arrow.clockwise")
                }

                Button(role: .destructive) {
                    settings.reset()
                } label: {
                    Label("Verbindung zurücksetzen", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Einstellungen")
        .onAppear { selectedCount = EntitySelection.selectedIDs().count }
    }
}

import SwiftUI
import ActivityKit

struct RelaySettingsView: View {
    @State private var relayURL = RelayConfig.url
    @State private var apiKey = RelayConfig.apiKey
    @State private var showAPIKey = false
    @State private var testResult: String?
    @State private var isTesting = false
    @State private var debugInfo: String = "Lade..."

    var body: some View {
        List {
            Section {
                TextField("http://192.168.1.100:8765", text: $relayURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)

                HStack {
                    if showAPIKey {
                        TextField("API Key", text: $apiKey)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                    } else {
                        SecureField("API Key", text: $apiKey)
                    }
                    Button {
                        showAPIKey.toggle()
                    } label: {
                        Image(systemName: showAPIKey ? "eye.slash" : "eye")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            } header: {
                Text("Push Relay Server")
            } footer: {
                Text("URL und API Key deines HA Live Notify Relay Add-ons. Den API Key findest du in den Add-on Logs.")
            }

            Section {
                Button {
                    save()
                } label: {
                    Label("Speichern", systemImage: "checkmark.circle")
                }
                .disabled(relayURL.isEmpty || apiKey.isEmpty)

                Button {
                    testConnection()
                } label: {
                    HStack {
                        Label("Verbindung testen", systemImage: "network")
                        if isTesting {
                            Spacer()
                            ProgressView()
                        }
                    }
                }
                .disabled(relayURL.isEmpty || apiKey.isEmpty || isTesting)

                if let result = testResult {
                    Text(result)
                        .font(.caption)
                        .foregroundStyle(result.contains("\u{2705}") ? .green : .red)
                }
            }

            Section("Debug") {
                Text(debugInfo)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Button {
                    refreshDebugInfo()
                } label: {
                    Label("Status aktualisieren", systemImage: "arrow.clockwise")
                }
            }

            if RelayConfig.isConfigured {
                Section {
                    Button(role: .destructive) {
                        RelayConfig.reset()
                        relayURL = ""
                        apiKey = ""
                        testResult = nil
                    } label: {
                        Label("Relay-Verbindung entfernen", systemImage: "trash")
                    }
                }
            }
        }
        .navigationTitle("Push Relay")
        .onAppear { refreshDebugInfo() }
    }

    private func refreshDebugInfo() {
        let authInfo = ActivityAuthorizationInfo()
        let configured = RelayConfig.isConfigured
        let hasURL = !RelayConfig.url.isEmpty
        let storedKey = RelayConfig.apiKey
        let hasKey = !storedKey.isEmpty
        let entities = EntitySelection.selectedIDs()
        let allActivities = Activity<TimerActivityAttributes>.activities
        let activeCount = allActivities.count
        let activityStates = allActivities.map { "\($0.attributes.entityID): \($0.activityState)" }

        var tokenInfo = "Keine"
        if let first = allActivities.first {
            tokenInfo = "\(first.attributes.entityID) hat Activity"
        }

        debugInfo = """
        Live Activities erlaubt: \(authInfo.areActivitiesEnabled ? "\u{2705}" : "\u{274C}")
        Frequent Push erlaubt: \(authInfo.frequentPushesEnabled ? "\u{2705}" : "\u{274C}")
        Relay URL: \(RelayConfig.url.isEmpty ? "\u{274C} leer" : RelayConfig.url)
        API Key: \(hasKey ? "\u{2705} Konfiguriert" : "\u{274C} LEER - nicht in Keychain!")
        Relay konfiguriert: \(configured ? "\u{2705}" : "\u{274C}")
        Entities: \(entities.count) - \(entities.joined(separator: ", "))
        System Activities: \(activeCount)
        \(activityStates.joined(separator: "\n"))
        Token: \(tokenInfo)
        """
    }

    private func save() {
        let trimmedURL = relayURL.trimmingCharacters(in: .whitespacesAndNewlines)

        if let warning = RelayConfig.validateURL(trimmedURL) {
            testResult = "\u{26A0}\u{FE0F} \(warning)"
        }

        RelayConfig.url = trimmedURL
        RelayConfig.apiKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if testResult == nil || testResult?.contains("\u{26A0}\u{FE0F}") == false {
            testResult = "\u{2705} Gespeichert"
        }

        Task {
            await PushTokenManager.shared.registerPushToStartToken()
        }
    }

    private func testConnection() {
        isTesting = true
        testResult = nil

        let urlString = relayURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: "\(urlString)/health") else {
            testResult = "\u{274C} Ungültige URL"
            isTesting = false
            return
        }

        Task {
            do {
                let (data, response) = try await URLSession.shared.data(from: url)
                if let http = response as? HTTPURLResponse, http.statusCode == 200,
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let status = json["status"] as? String, status == "ok"
                {
                     testResult = "\u{2705} Verbunden"
                } else {
                    testResult = "\u{274C} Server antwortet nicht korrekt"
                }
            } catch {
                testResult = "\u{274C} \(error.localizedDescription)"
            }
            isTesting = false
        }
    }
}

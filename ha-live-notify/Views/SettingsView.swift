import SwiftUI

struct SettingsView: View {
    @Bindable var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss
    @State private var url: String = ""
    @State private var token: String = ""
    @State private var showToken = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("http://homeassistant.local:8123", text: $url)
                        .textContentType(.URL)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("Home Assistant URL")
                } footer: {
                    Text("Die Adresse deiner Home Assistant Instanz.")
                }

                Section {
                    HStack {
                        if showToken {
                            TextField("Token", text: $token)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("Long-Lived Access Token", text: $token)
                        }
                        Button {
                            showToken.toggle()
                        } label: {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                } header: {
                    Text("Access Token")
                } footer: {
                    Text("Erstelle einen Token unter Profil → Sicherheit → Long-Lived Access Tokens.")
                }

                if settings.isConfigured {
                    Section {
                        Button("Verbindung zurücksetzen", role: .destructive) {
                            settings.reset()
                            url = ""
                            token = ""
                        }
                    }
                }
            }
            .navigationTitle("Einstellungen")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Speichern") {
                        settings.config = ServerConfig(
                            baseURL: url,
                            accessToken: token
                        )
                        dismiss()
                    }
                    .disabled(url.isEmpty || token.isEmpty)
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            url = settings.config.baseURL
            token = settings.config.accessToken
        }
        .onDisappear {
            // Clear token from view memory when sheet closes
            token = ""
        }
    }
}

import SwiftUI

struct EntityConfigView: View {
    let entity: HAEntity
    @State private var config: EntityConfig
    @Environment(\.dismiss) private var dismiss

    init(entity: HAEntity) {
        self.entity = entity
        self._config = State(initialValue: EntityConfigStore.config(for: entity.entityID))
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(config.color.opacity(0.15))
                                .frame(width: 50, height: 50)
                            Image(systemName: config.iconName)
                                .font(.title2)
                                .foregroundStyle(config.color)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(entity.friendlyName)
                                .font(.headline)
                            Text("0:42:15")
                                .font(.title2.monospacedDigit().bold())
                                .foregroundStyle(config.color)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Vorschau")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 5), spacing: 16) {
                        ForEach(EntityConfig.availableIcons, id: \.self) { icon in
                            Button {
                                config.iconName = icon
                            } label: {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(config.iconName == icon ? config.color.opacity(0.15) : Color.clear)
                                        .frame(width: 52, height: 52)
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(config.iconName == icon ? config.color : .clear, lineWidth: 2)
                                        .frame(width: 52, height: 52)
                                    Image(systemName: icon)
                                        .font(.title2)
                                        .foregroundStyle(config.iconName == icon ? config.color : .secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Icon")
                }

                Section {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                        ForEach(EntityConfig.availableColors, id: \.hex) { color in
                            Button {
                                config.colorHex = color.hex
                            } label: {
                                VStack(spacing: 6) {
                                    ZStack {
                                        Circle()
                                            .fill(Color(hex: color.hex) ?? .orange)
                                            .frame(width: 40, height: 40)
                                        if config.colorHex == color.hex {
                                            Image(systemName: "checkmark")
                                                .font(.body.bold())
                                                .foregroundStyle(.white)
                                        }
                                    }
                                    Text(color.name)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                } header: {
                    Text("Farbe")
                }

                Section {
                    Toggle(isOn: $config.invertProgress) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fortschritt umkehren")
                            Text(config.invertProgress
                                 ? "Bar leert sich von voll → leer"
                                 : "Bar füllt sich von leer → voll")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .tint(config.color)
                } header: {
                    Text("Fortschrittsbalken")
                }
            }
            .navigationTitle(entity.friendlyName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Fertig") {
                        EntityConfigStore.setConfig(config, for: entity.entityID)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") {
                        dismiss()
                    }
                }
            }
        }
    }
}

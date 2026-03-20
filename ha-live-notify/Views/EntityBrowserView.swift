import SwiftUI

struct EntityBrowserView: View {
    let entities: [HAEntity]
    let onStartTimer: (HAEntity) -> Void
    var onRefresh: (() -> Void)?

    @State private var searchText = ""
    @State private var configEntity: HAEntity?

    private var filteredEntities: [HAEntity] {
        if searchText.isEmpty {
            return entities
        }
        let query = searchText.lowercased()
        return entities.filter {
            $0.friendlyName.lowercased().contains(query) ||
            $0.entityID.lowercased().contains(query)
        }
    }

    var body: some View {
        List {
            if filteredEntities.isEmpty {
                ContentUnavailableView(
                    "Keine Timer gefunden",
                    systemImage: "timer",
                    description: Text("Es wurden keine Timer-Entities mit dem Label \"live-notify\" gefunden.")
                )
            } else {
                ForEach(filteredEntities) { entity in
                    EntityRow(
                        entity: entity,
                        config: EntityConfigStore.config(for: entity.entityID),
                        onStart: { onStartTimer(entity) },
                        onConfigure: { configEntity = entity }
                    )
                }
            }
        }
        .searchable(text: $searchText, prompt: "Entity suchen...")
        .refreshable { onRefresh?() }
        .navigationTitle("Timer")
        .sheet(item: $configEntity) { entity in
            EntityConfigView(entity: entity)
        }
    }
}

private struct EntityRow: View {
    let entity: HAEntity
    let config: EntityConfig
    let onStart: () -> Void
    let onConfigure: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Configurable icon with color
            ZStack {
                Circle()
                    .fill(config.color.opacity(0.12))
                    .frame(width: 40, height: 40)
                Image(systemName: config.iconName)
                    .font(.title3)
                    .foregroundStyle(config.color)
            }
            .onTapGesture { onConfigure() }

            VStack(alignment: .leading, spacing: 2) {
                Text(entity.friendlyName)
                    .font(.body)
                Text(stateLabel)
                    .font(.caption)
                    .foregroundStyle(stateColor)
            }

            Spacer()

            if entity.state == "active", let finishesAt = entity.finishesAt {
                Text(finishesAt, style: .timer)
                    .font(.subheadline.monospacedDigit())
                    .foregroundStyle(config.color)
            }

            // Start Live Activity button
            if entity.state == "active" {
                Button {
                    onStart()
                } label: {
                    Image(systemName: "bell.badge")
                        .font(.body)
                }
                .buttonStyle(.bordered)
                .tint(config.color)
            }
        }
        .padding(.vertical, 4)
    }

    private var stateLabel: String {
        switch entity.state {
        case "active": "Läuft"
        case "paused": "Pausiert"
        case "idle": "Inaktiv"
        default: entity.state
        }
    }

    private var stateColor: Color {
        switch entity.state {
        case "active": .green
        case "paused": .yellow
        default: .secondary
        }
    }
}

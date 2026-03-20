import SwiftUI

struct EntitySelectionView: View {
    let allTimerEntities: [HAEntity]
    @State private var selectedIDs: Set<String> = []
    @State private var searchText = ""

    private var filteredEntities: [HAEntity] {
        if searchText.isEmpty {
            return allTimerEntities
        }
        let query = searchText.lowercased()
        return allTimerEntities.filter {
            $0.friendlyName.lowercased().contains(query) ||
            $0.entityID.lowercased().contains(query)
        }
    }

    private var selectedEntities: [HAEntity] {
        filteredEntities.filter { selectedIDs.contains($0.entityID) }
    }

    private var unselectedEntities: [HAEntity] {
        filteredEntities.filter { !selectedIDs.contains($0.entityID) }
    }

    var body: some View {
        List {
            if !selectedEntities.isEmpty {
                Section("Aktiv") {
                    ForEach(selectedEntities) { entity in
                        entityRow(entity, isSelected: true)
                    }
                }
            }

            Section(unselectedEntities.isEmpty ? "Keine weiteren Timer" : "Verfügbar") {
                if allTimerEntities.isEmpty {
                    ContentUnavailableView(
                        "Keine Timer gefunden",
                        systemImage: "timer",
                        description: Text("Verbinde dich mit Home Assistant um Timer zu sehen.")
                    )
                } else {
                    ForEach(unselectedEntities) { entity in
                        entityRow(entity, isSelected: false)
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Timer suchen...")
        .navigationTitle("Entities")
        .onAppear { selectedIDs = EntitySelection.selectedIDs() }
    }

    private func entityRow(_ entity: HAEntity, isSelected: Bool) -> some View {
        let config = EntityConfigStore.config(for: entity.entityID)

        return HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(config.color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: config.iconName)
                    .font(.body)
                    .foregroundStyle(config.color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(entity.friendlyName)
                    .font(.body)
                Text(entity.entityID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                toggle(entity.entityID)
            } label: {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? config.color : .secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 2)
    }

    private func toggle(_ entityID: String) {
        let newState = !selectedIDs.contains(entityID)
        EntitySelection.setSelected(entityID, selected: newState)
        if newState {
            selectedIDs.insert(entityID)
        } else {
            selectedIDs.remove(entityID)
        }
    }
}

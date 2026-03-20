import ActivityKit
import SwiftUI

struct ActiveActivitiesView: View {
    let activities: [Activity<TimerActivityAttributes>]
    let onEnd: (Activity<TimerActivityAttributes>) -> Void

    var body: some View {
        List {
            if activities.isEmpty {
                ContentUnavailableView(
                    "Keine aktiven Live Activities",
                    systemImage: "bell.slash",
                    description: Text("Starte eine Live Activity aus dem Timer-Tab.")
                )
            } else {
                ForEach(activities, id: \.id) { activity in
                    ActivityRow(activity: activity, onEnd: { onEnd(activity) })
                }
            }
        }
        .navigationTitle("Aktiv")
    }
}

private struct ActivityRow: View {
    let activity: Activity<TimerActivityAttributes>
    let onEnd: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: activity.attributes.iconName)
                .font(.title2)
                .foregroundStyle(.orange)
                .frame(width: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(activity.attributes.deviceName)
                    .font(.body)
                Text(activity.attributes.entityID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(activity.content.state.endTime, style: .timer)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.orange)

            Button {
                onEnd()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}

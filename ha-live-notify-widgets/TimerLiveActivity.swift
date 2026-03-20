import ActivityKit
import SwiftUI
import WidgetKit

struct TimerLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TimerActivityAttributes.self) { context in
            lockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: iconName(context))
                        .font(.title2)
                        .foregroundStyle(accentColor(context))
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.attributes.deviceName)
                        .font(.headline)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    timerDisplay(context: context)
                }

                DynamicIslandExpandedRegion(.bottom) {
                    progressBar(context: context)
                }
            } compactLeading: {
                Image(systemName: iconName(context))
                    .foregroundStyle(accentColor(context))
            } compactTrailing: {
                compactTrailingView(context: context)
            } minimal: {
                Image(systemName: iconName(context))
                    .foregroundStyle(accentColor(context))
            }
        }
    }

    private func accentColor(_ context: ActivityViewContext<TimerActivityAttributes>) -> Color {
        Color(hex: context.attributes.accentColorHex) ?? .orange
    }

    private func iconName(_ context: ActivityViewContext<TimerActivityAttributes>) -> String {
        switch context.state.state {
        case .paused: "pause.circle.fill"
        case .finished: "checkmark.circle.fill"
        default: context.attributes.iconName
        }
    }

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        let accent = accentColor(context)

        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(accent.opacity(0.15))
                    .frame(width: 50, height: 50)
                Image(systemName: iconName(context))
                    .font(.title2)
                    .foregroundStyle(accent)
            }
            .frame(width: 50)

            VStack(spacing: 6) {
                HStack {
                    Text(context.attributes.deviceName)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    timerDisplay(context: context)
                        .frame(width: 75, alignment: .trailing)
                }

                progressBar(context: context)
            }
        }
        .padding(16)
        .activityBackgroundTint(.black.opacity(0.7))
        .activitySystemActionForegroundColor(.white)
    }

    private let barHeight: CGFloat = 4

    @ViewBuilder
    private func progressBar(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        let accent = accentColor(context)
        let invert = context.attributes.invertProgress

        switch context.state.state {
        case .active:
            let startTime = context.state.endTime.addingTimeInterval(-context.state.totalDuration)

            if invert {
                ProgressView(
                    timerInterval: startTime...context.state.endTime,
                    countsDown: true,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.linear)
                .tint(accent)
                .frame(height: barHeight)
                .scaleEffect(x: 1, y: 0.6)
            } else {
                ProgressView(
                    timerInterval: startTime...context.state.endTime,
                    countsDown: false,
                    label: { EmptyView() },
                    currentValueLabel: { EmptyView() }
                )
                .progressViewStyle(.linear)
                .tint(accent)
                .frame(height: barHeight)
                .scaleEffect(x: 1, y: 0.6)
            }

        case .paused:
            GeometryReader { geo in
                let rawProgress = context.state.progress ?? 0.5
                let displayProgress = invert ? (1.0 - rawProgress) : rawProgress

                ZStack(alignment: .leading) {
                    Capsule().fill(accent.opacity(0.2))
                    Capsule()
                        .fill(accent)
                        .frame(width: geo.size.width * displayProgress)
                }
            }
            .frame(height: barHeight)

        case .finished, .idle:
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.green.opacity(0.2))
                    Capsule()
                        .fill(Color.green)
                        .frame(width: geo.size.width)
                }
            }
            .frame(height: barHeight)
        }
    }

    @ViewBuilder
    private func timerDisplay(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        let accent = accentColor(context)

        Group {
            switch context.state.state {
            case .active:
                if context.state.endTime > Date() {
                    Text(context.state.endTime, style: .timer)
                        .font(.title2.monospacedDigit().bold())
                        .foregroundStyle(accent)
                } else {
                    Text("Fertig")
                        .font(.subheadline.bold())
                        .foregroundStyle(.green)
                }
            case .paused:
                Text("Pausiert")
                    .font(.subheadline.bold())
                    .foregroundStyle(accent)
            case .finished, .idle:
                Text("Fertig")
                    .font(.subheadline.bold())
                    .foregroundStyle(.green)
            }
        }
        .multilineTextAlignment(.trailing)
        .frame(height: 32)
    }

    @ViewBuilder
    private func compactTrailingView(context: ActivityViewContext<TimerActivityAttributes>) -> some View {
        switch context.state.state {
        case .active:
            if context.state.endTime > Date() {
                Text(context.state.endTime, style: .timer)
                    .monospacedDigit()
                    .font(.caption)
                    .frame(minWidth: 40)
            } else {
                Image(systemName: "checkmark")
                    .foregroundStyle(.green)
            }
        case .paused:
            Text("II")
                .font(.caption.bold())
                .foregroundStyle(accentColor(context))
        case .finished, .idle:
            Image(systemName: "checkmark")
                .foregroundStyle(.green)
        }
    }
}

extension Color {
    init?(hex: String) {
        var h = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if h.hasPrefix("#") { h.removeFirst() }
        guard h.count == 6,
              let int = UInt64(h, radix: 16)
        else { return nil }

        self.init(
            red: Double((int >> 16) & 0xFF) / 255,
            green: Double((int >> 8) & 0xFF) / 255,
            blue: Double(int & 0xFF) / 255
        )
    }
}

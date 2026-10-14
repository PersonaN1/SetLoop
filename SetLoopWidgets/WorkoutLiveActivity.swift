import ActivityKit
import SetLoopCore
import SwiftUI
import WidgetKit

/// Lock screen and Dynamic Island (DESIGN V10). Countdown runs in the system, without the app.
struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            LockScreenView(state: context.state, timerName: context.attributes.timerName)
                .activityBackgroundTint(context.state.color.color)
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let state = context.state
            let accent = state.color.lightened.color
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Text(state.stepName).font(.headline).foregroundStyle(accent)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    CountdownText(state: state).font(.system(.title, design: .rounded, weight: .bold))
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(state.positionText)
                        if let next = state.nextText { Text(next) }
                    }
                    .font(.footnote)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } compactLeading: {
                ProgressRing(state: state).frame(width: 18, height: 18)
            } compactTrailing: {
                CountdownText(state: state)
                    .font(.system(.body, design: .rounded, weight: .bold))
                    .foregroundStyle(accent)
                    .frame(maxWidth: 52)
            } minimal: {
                ProgressRing(state: state).frame(width: 18, height: 18)
            }
        }
    }
}

private struct LockScreenView: View {
    let state: WorkoutActivityAttributes.ContentState
    let timerName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(state.stepName).font(.headline)
                Spacer()
                Text(timerName).font(.footnote).opacity(0.85)
            }
            CountdownText(state: state)
                .font(.system(size: 52, weight: .bold, design: .rounded))
            Text([state.positionText, state.nextText].compactMap { $0 }.filter { !$0.isEmpty }.joined(separator: "\n"))
                .font(.footnote)
                .opacity(0.9)
            // TODO: Pause / Skip buttons via LiveActivityIntent (TECH T10).
        }
        .foregroundStyle(.white)
        .padding()
    }
}

private struct CountdownText: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        Group {
            if let start = state.stepStart, let end = state.stepEnd {
                Text(timerInterval: start...end, countsDown: true)
            } else {
                let seconds = Int((state.pausedRemaining ?? 0).rounded(.up))
                Text(String(format: "%d:%02d", seconds / 60, seconds % 60))
            }
        }
        .monospacedDigit()
        .multilineTextAlignment(.trailing)
    }
}

private struct ProgressRing: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if let start = state.stepStart, let end = state.stepEnd {
            ProgressView(timerInterval: start...end, countsDown: true) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.circular)
                .tint(state.color.lightened.color)
        } else {
            Image(systemName: "pause.fill").foregroundStyle(state.color.lightened.color)
        }
    }
}

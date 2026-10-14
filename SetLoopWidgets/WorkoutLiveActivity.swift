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
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(state.positionText)
                            if let next = state.nextText { Text(next) }
                        }
                        .font(.footnote)
                        .lineLimit(1)
                        Spacer(minLength: 8)
                        ActivityButtons(state: state, tint: accent)
                    }
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
        // The lock screen card is limited to ~160 pt: header, one row with texts and digits,
        // progress bar with the buttons.
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(state.stepName).font(.headline).lineLimit(1)
                Spacer()
                Text(timerName).font(.footnote).opacity(0.85).lineLimit(1)
            }
            HStack(alignment: .bottom) {
                VStack(alignment: .leading, spacing: 2) {
                    if !state.positionText.isEmpty { Text(state.positionText) }
                    if let next = state.nextText { Text(next) }
                }
                .font(.footnote)
                .lineLimit(1)
                .opacity(0.9)
                Spacer(minLength: 8)
                CountdownText(state: state)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .frame(maxWidth: 130, alignment: .trailing)
            }
            HStack(spacing: 12) {
                StepProgressBar(state: state)
                // Paused, the bar is gone and the buttons stay on the right.
                Spacer(minLength: 0)
                ActivityButtons(state: state, tint: .white)
            }
        }
        .foregroundStyle(.white)
        .padding(16)
    }
}

/// Pause/Resume and Skip; the app performs them (TECH T10).
private struct ActivityButtons: View {
    let state: WorkoutActivityAttributes.ContentState
    let tint: Color

    var body: some View {
        HStack(spacing: 10) {
            Button(intent: TogglePauseIntent()) {
                icon(state.isPaused ? "play.fill" : "pause.fill")
            }
            .accessibilityLabel(state.isPaused ? "Resume" : "Pause")
            Button(intent: SkipStepIntent()) {
                icon("forward.end.fill")
            }
            .accessibilityLabel("Skip")
        }
        .buttonStyle(.plain)
    }

    private func icon(_ name: String) -> some View {
        Image(systemName: name)
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(tint)
            .frame(width: 36, height: 36)
            .background(tint.opacity(0.22), in: Circle())
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

private struct StepProgressBar: View {
    let state: WorkoutActivityAttributes.ContentState

    var body: some View {
        if let start = state.stepStart, let end = state.stepEnd {
            ProgressView(timerInterval: start...end, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
                .progressViewStyle(.linear)
                .tint(.white)
        }
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

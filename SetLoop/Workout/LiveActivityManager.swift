import ActivityKit
import Foundation
import SetLoopCore

/// Starts, updates and ends the workout Live Activity locally, without push (TECH T10).
@MainActor
final class LiveActivityManager {
    private var activity: Activity<WorkoutActivityAttributes>?

    func start(timerName: String, state: WorkoutActivityAttributes.ContentState?) {
        guard let state, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // TODO: respect the "Show on lock screen" setting (SPEC D7).
        activity = try? Activity.request(
            attributes: WorkoutActivityAttributes(timerName: timerName),
            content: .init(state: state, staleDate: nil)
        )
    }

    func update(_ state: WorkoutActivityAttributes.ContentState?) {
        guard let activity, let state else { return }
        Task { await activity.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activity else { return }
        self.activity = nil
        Task { await activity.end(nil, dismissalPolicy: .after(.now.addingTimeInterval(120))) }
    }
}

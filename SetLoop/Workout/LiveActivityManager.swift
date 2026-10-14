import ActivityKit
import Foundation
import SetLoopCore

/// Starts, updates and ends the workout Live Activity locally, without push (TECH T10).
@MainActor
final class LiveActivityManager {
    /// Only the ID is kept: `Activity` is not Sendable, so each task looks it up off the main actor.
    private var activityID: String?

    func start(timerName: String, state: WorkoutActivityAttributes.ContentState?) {
        guard let state, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        // TODO: respect the "Show on lock screen" setting (SPEC D7).
        activityID = try? Activity.request(
            attributes: WorkoutActivityAttributes(timerName: timerName),
            content: .init(state: state, staleDate: nil)
        ).id
    }

    func update(_ state: WorkoutActivityAttributes.ContentState?) {
        guard let activityID, let state else { return }
        Task.detached { await Self.activity(activityID)?.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activityID else { return }
        self.activityID = nil
        Task.detached {
            await Self.activity(activityID)?.end(nil, dismissalPolicy: .after(.now.addingTimeInterval(120)))
        }
    }

    private nonisolated static func activity(_ id: String) -> Activity<WorkoutActivityAttributes>? {
        Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
    }
}

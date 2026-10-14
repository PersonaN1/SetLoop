import ActivityKit
import Foundation
import SetLoopCore

/// Starts, updates and ends the workout Live Activity locally, without push (TECH T10).
@MainActor
final class LiveActivityManager {
    /// Only the ID is kept: `Activity` is not Sendable, so each task looks it up off the main actor.
    private var activityID: String?

    init() {
        // Activities outlive the app: a killed or reinstalled app leaves its last one on the lock screen.
        Self.endAll()
    }

    func start(timerName: String, state: WorkoutActivityAttributes.ContentState?) {
        Self.endAll()
        guard let state, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
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
        // Removed at once: a finished workout has nothing left to show (SPEC D7).
        Task.detached { await Self.activity(activityID)?.end(nil, dismissalPolicy: .immediate) }
    }

    private nonisolated static func endAll() {
        Task.detached {
            for activity in Activity<WorkoutActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private nonisolated static func activity(_ id: String) -> Activity<WorkoutActivityAttributes>? {
        Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
    }
}

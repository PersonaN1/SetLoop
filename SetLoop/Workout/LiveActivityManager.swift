import ActivityKit
import Foundation
import SetLoopCore

/// Starts, updates and ends the workout Live Activity locally, without push (TECH T10).
@MainActor
final class LiveActivityManager {
    /// Only the ID is kept: `Activity` is not Sendable, so each task looks it up off the main actor.
    private var activityID: String?
    /// Updates are delivered one after another, so an older state never lands after a newer one.
    private var lastTask: Task<Void, Never>?

    init() {
        // Activities outlive the app: a killed or reinstalled app leaves its last one on the lock screen.
        Self.endExisting()
    }

    func start(timerName: String, state: WorkoutActivityAttributes.ContentState?) {
        // Before the request: the new activity must not be in the list that gets ended.
        Self.endExisting()
        guard let state, ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        activityID = try? Activity.request(
            attributes: WorkoutActivityAttributes(timerName: timerName.cappedName),
            content: .init(state: state, staleDate: nil)
        ).id
    }

    func update(_ state: WorkoutActivityAttributes.ContentState?) {
        guard let activityID, let state else { return }
        enqueue { await Self.activity(activityID)?.update(.init(state: state, staleDate: nil)) }
    }

    func end() {
        guard let activityID else { return }
        self.activityID = nil
        // Removed at once: a finished workout has nothing left to show (SPEC D7).
        enqueue { await Self.activity(activityID)?.end(nil, dismissalPolicy: .immediate) }
    }

    /// Waits until every update and end requested so far is delivered.
    func flush() async {
        await lastTask?.value
    }

    private func enqueue(_ work: @escaping @Sendable () async -> Void) {
        let previous = lastTask
        lastTask = Task.detached {
            await previous?.value
            await work()
        }
    }

    /// Ends the activities that exist right now. The IDs are taken synchronously, so an activity
    /// requested after this call survives even if the ending task runs later.
    private nonisolated static func endExisting() {
        let ids = Activity<WorkoutActivityAttributes>.activities.map(\.id)
        guard !ids.isEmpty else { return }
        Task.detached {
            for id in ids {
                await activity(id)?.end(nil, dismissalPolicy: .immediate)
            }
        }
    }

    private nonisolated static func activity(_ id: String) -> Activity<WorkoutActivityAttributes>? {
        Activity<WorkoutActivityAttributes>.activities.first { $0.id == id }
    }
}

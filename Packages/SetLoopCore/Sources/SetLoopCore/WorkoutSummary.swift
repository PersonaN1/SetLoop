import Foundation

/// What the summary screen and history show about a finished workout (SPEC D10, DESIGN V5).
public struct WorkoutSummary: Equatable, Sendable {
    public var status: WorkoutStatus
    /// Active time without pauses, whole seconds.
    public var duration: Int
    /// Steps actually reached, with outcomes.
    public var steps: [StepRecord]
    /// Steps in the plan. A final rest removed by "Skip last rest" is not part of the plan (SPEC D10).
    public var totalSteps: Int

    public init(status: WorkoutStatus, duration: Int, steps: [StepRecord], totalSteps: Int) {
        self.status = status
        self.duration = duration
        self.steps = steps
        self.totalSteps = totalSteps
    }

    /// Nil until the workout has finished.
    public init?(engine: WorkoutEngine, at now: TimeInterval) {
        guard case .finished(let status) = engine.phase else { return nil }
        self.init(
            status: status,
            duration: Int(engine.activeTime(at: now).rounded()),
            steps: engine.log,
            totalSteps: engine.plan.steps.count
        )
    }

    public var completedSteps: Int { steps.completedCount }

    public func time(of category: StepType.Category) -> Int { steps.time(of: category) }
}

extension Array where Element == StepRecord {
    public var completedCount: Int { filter { $0.outcome == .completed }.count }

    /// Full durations of completed steps; skipped and interrupted steps do not count.
    public func time(of category: StepType.Category) -> Int {
        filter { $0.outcome == .completed && $0.step.type.category == category }.reduce(0) { $0 + $1.step.duration }
    }
}

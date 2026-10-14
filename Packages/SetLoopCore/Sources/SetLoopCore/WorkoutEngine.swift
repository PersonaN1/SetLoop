import Foundation

/// Time-based workout state machine (TECH T9).
///
/// The engine never ticks: all state is derived from timestamps passed in by the caller.
/// `now` is any monotonic clock in seconds (the app uses `ContinuousClock`, tests use plain numbers).
public struct WorkoutEngine: Sendable {
    public enum Phase: Equatable, Sendable {
        case notStarted
        case running
        case paused
        case finished(WorkoutStatus)
    }

    /// Within this many seconds of a step start, "Back" goes to the previous step (SPEC D3).
    public static let backThreshold: TimeInterval = 2
    /// Countdown cues are played this many seconds before a step ends (SPEC D5).
    public static let countdownSeconds = 3

    public let plan: WorkoutPlan
    public private(set) var phase: Phase = .notStarted
    public private(set) var currentIndex = 0
    /// Steps actually reached, in plan order (SPEC D10).
    public private(set) var log: [StepRecord] = []

    private var stepElapsedBase: TimeInterval = 0
    private var activeTimeBase: TimeInterval = 0
    private var runningSince: TimeInterval?

    public init(plan: WorkoutPlan) {
        self.plan = plan
    }

    // MARK: - Queries

    public var currentStep: PlannedStep? {
        plan.steps.indices.contains(currentIndex) ? plan.steps[currentIndex] : nil
    }

    public var nextStep: PlannedStep? {
        plan.steps.indices.contains(currentIndex + 1) ? plan.steps[currentIndex + 1] : nil
    }

    public func stepElapsed(at now: TimeInterval) -> TimeInterval {
        stepElapsedBase + (runningSince.map { now - $0 } ?? 0)
    }

    public func stepRemaining(at now: TimeInterval) -> TimeInterval {
        guard let step = currentStep else { return 0 }
        return max(TimeInterval(step.duration) - stepElapsed(at: now), 0)
    }

    /// Time spent running, without pauses. Repeated steps (after "Back") count again.
    public func activeTime(at now: TimeInterval) -> TimeInterval {
        activeTimeBase + (runningSince.map { now - $0 } ?? 0)
    }

    /// The next moment something audible happens; the controller sleeps until then.
    public func nextCue(at now: TimeInterval) -> Cue? {
        guard phase == .running, let step = currentStep, let since = runningSince else { return nil }
        let stepEnd = since - stepElapsedBase + TimeInterval(step.duration)
        if step.duration > Self.countdownSeconds {
            for left in stride(from: Self.countdownSeconds, through: 1, by: -1) {
                let time = stepEnd - TimeInterval(left)
                if time > now { return Cue(time: time, kind: .countdown(left)) }
            }
        }
        return Cue(time: max(stepEnd, now), kind: .stepEnd)
    }

    // MARK: - Commands

    public mutating func start(at now: TimeInterval) {
        guard phase == .notStarted else { return }
        guard !plan.steps.isEmpty else { phase = .finished(.complete); return }
        phase = .running
        runningSince = now
    }

    /// Moves through steps that ended by `now`. Returns what happened, oldest first.
    @discardableResult
    public mutating func update(at now: TimeInterval) -> [Transition] {
        guard phase == .running else { return [] }
        var transitions: [Transition] = []
        while let step = currentStep, stepElapsed(at: now) >= TimeInterval(step.duration) {
            let overflow = stepElapsed(at: now) - TimeInterval(step.duration)
            log.append(StepRecord(planIndex: currentIndex, step: step.step, outcome: .completed, elapsed: step.duration))
            advance(startingAt: now - overflow, now: now)
            transitions.append(phase == .running ? .stepStarted(currentIndex) : .finished)
        }
        return transitions
    }

    public mutating func pause(at now: TimeInterval) {
        update(at: now)
        guard phase == .running, let since = runningSince else { return }
        stepElapsedBase += now - since
        activeTimeBase += now - since
        runningSince = nil
        phase = .paused
    }

    public mutating func resume(at now: TimeInterval) {
        guard phase == .paused else { return }
        runningSince = now
        phase = .running
    }

    public mutating func skip(at now: TimeInterval) {
        update(at: now)
        guard isActive, let step = currentStep else { return }
        log.append(StepRecord(planIndex: currentIndex, step: step.step, outcome: .skipped,
                              elapsed: Self.seconds(stepElapsed(at: now))))
        advance(startingAt: now, now: now)
    }

    /// Restarts the current step, or goes to the previous one within the first 2 s (SPEC D3).
    public mutating func back(at now: TimeInterval) {
        update(at: now)
        guard isActive else { return }
        if stepElapsed(at: now) < Self.backThreshold, currentIndex > 0 {
            currentIndex -= 1
            log.removeAll { $0.planIndex >= currentIndex }
        }
        restartStep(at: now)
    }

    /// Early finish from pause (SPEC D3). The current step is recorded as interrupted.
    public mutating func finish(at now: TimeInterval) {
        update(at: now)
        guard isActive else { return }
        if let step = currentStep, stepElapsed(at: now) > 0 {
            log.append(StepRecord(planIndex: currentIndex, step: step.step, outcome: .interrupted,
                                  elapsed: Self.seconds(stepElapsed(at: now))))
        }
        stopClock(at: now)
        phase = .finished(.partial)
    }

    // MARK: - Private

    private var isActive: Bool { phase == .running || phase == .paused }

    private static func seconds(_ time: TimeInterval) -> Int { Int(time.rounded()) }

    private mutating func advance(startingAt start: TimeInterval, now: TimeInterval) {
        let wasRunning = phase == .running
        if wasRunning, let since = runningSince { activeTimeBase += start - since }
        currentIndex += 1
        stepElapsedBase = 0
        if currentStep == nil {
            runningSince = nil
            phase = .finished(.complete)
        } else {
            runningSince = wasRunning ? start : nil
        }
    }

    private mutating func restartStep(at now: TimeInterval) {
        if let since = runningSince {
            activeTimeBase += now - since
            runningSince = now
        }
        stepElapsedBase = 0
    }

    private mutating func stopClock(at now: TimeInterval) {
        if let since = runningSince { activeTimeBase += now - since }
        runningSince = nil
    }
}

public enum WorkoutStatus: String, Codable, Sendable {
    /// Reached the end, even with skipped steps.
    case complete
    /// Finished early.
    case partial
}

public struct StepRecord: Codable, Hashable, Sendable {
    public enum Outcome: String, Codable, Sendable {
        case completed
        /// Only when "Skip" was pressed (SPEC D10).
        case skipped
        /// The step the workout was finished on early.
        case interrupted
    }

    public var planIndex: Int
    public var step: Step
    public var outcome: Outcome
    /// Seconds actually spent on the step: the full duration when completed, less when skipped or interrupted.
    public var elapsed: Int

    public init(planIndex: Int, step: Step, outcome: Outcome, elapsed: Int) {
        self.planIndex = planIndex
        self.step = step
        self.outcome = outcome
        self.elapsed = elapsed
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        planIndex = try container.decode(Int.self, forKey: .planIndex)
        step = try container.decode(Step.self, forKey: .step)
        outcome = try container.decode(Outcome.self, forKey: .outcome)
        // Records saved before `elapsed` existed only counted completed steps.
        elapsed = try container.decodeIfPresent(Int.self, forKey: .elapsed) ?? (outcome == .completed ? step.duration : 0)
    }
}

public struct Cue: Equatable, Sendable {
    public enum Kind: Equatable, Sendable {
        case countdown(Int)
        case stepEnd
    }

    public var time: TimeInterval
    public var kind: Kind
}

public enum Transition: Equatable, Sendable {
    case stepStarted(Int)
    case finished
}

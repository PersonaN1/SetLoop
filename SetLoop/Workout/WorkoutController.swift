import Foundation
import Observation
import SetLoopCore

/// The single running workout: drives the engine, Live Activity and (later) sound, haptics and interruptions (TECH T4, T9).
@MainActor
@Observable
final class WorkoutController {
    private(set) var engine: WorkoutEngine?
    private(set) var timerName = ""
    /// Kept for the history record, so "Repeat" works after the timer is edited or deleted.
    private(set) var definition = TimerDefinition(blocks: [])
    private(set) var startedAt = Date.now
    var colors = StepColors.default

    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant
    private var cueTask: Task<Void, Never>?
    private let liveActivity = LiveActivityManager()

    init() {
        origin = clock.now
    }

    var isPresented: Bool { engine != nil }

    /// Available once the workout has finished.
    var summary: WorkoutSummary? { engine.flatMap { WorkoutSummary(engine: $0, at: now) } }

    /// Monotonic seconds used by the engine.
    var now: TimeInterval {
        let elapsed = clock.now - origin
        return TimeInterval(elapsed.components.seconds) + TimeInterval(elapsed.components.attoseconds) / 1e18
    }

    // MARK: - Commands

    func start(_ timer: SavedTimer) {
        start(name: timer.name, definition: timer.definition)
    }

    func start(name: String, definition: TimerDefinition) {
        guard engine == nil else { return }
        var engine = WorkoutEngine(plan: definition.plan)
        engine.start(at: now)
        self.engine = engine
        self.definition = definition
        timerName = name
        startedAt = .now
        liveActivity.start(timerName: name, state: activityState())
        scheduleNextCue()
    }

    func pause() { mutate { $0.pause(at: $1) } }
    func resume() { mutate { $0.resume(at: $1) } }
    func togglePause() { engine?.phase == .paused ? resume() : pause() }
    func skip() { mutate { $0.skip(at: $1) } }
    func back() { mutate { $0.back(at: $1) } }
    func finish() { mutate { $0.finish(at: $1) } }

    /// Closes the summary screen.
    func close() {
        cueTask?.cancel()
        engine = nil
        liveActivity.end()
    }

    // MARK: - Private

    private func mutate(_ change: (inout WorkoutEngine, TimeInterval) -> Void) {
        guard var engine else { return }
        change(&engine, now)
        self.engine = engine
        didChangeState()
    }

    private func didChangeState() {
        if case .finished = engine?.phase {
            cueTask?.cancel()
            liveActivity.end()
        } else {
            liveActivity.update(activityState())
            scheduleNextCue()
        }
    }

    /// Sleeps until the next countdown tick or step end instead of ticking constantly.
    private func scheduleNextCue() {
        cueTask?.cancel()
        guard let cue = engine?.nextCue(at: now) else { return }
        let delay = max(cue.time - now, 0)
        cueTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(delay), tolerance: .milliseconds(20))
            guard !Task.isCancelled else { return }
            self?.handle(cue)
        }
    }

    private func handle(_ cue: Cue) {
        guard var engine else { return }
        // TODO: play countdown / step sounds, voice and haptics (TECH T6).
        let transitions = engine.update(at: now)
        self.engine = engine
        if transitions.isEmpty {
            scheduleNextCue()
        } else {
            didChangeState()
        }
    }

    private func activityState() -> WorkoutActivityAttributes.ContentState? {
        guard let engine, let step = engine.currentStep else { return nil }
        let remaining = engine.stepRemaining(at: now)
        let running = engine.phase == .running
        let stepEnd = Date.now.addingTimeInterval(remaining)
        return .init(
            stepName: step.step.name,
            stepType: step.type,
            color: colors[step.type],
            stepEnd: running ? stepEnd : nil,
            stepStart: running ? stepEnd.addingTimeInterval(-TimeInterval(step.duration)) : nil,
            pausedRemaining: running ? nil : remaining,
            positionText: WorkoutFormat.position(step.position),
            nextText: engine.nextStep.map { WorkoutFormat.next($0) }
        )
    }
}

import Foundation
import Observation
import SetLoopCore
import UIKit

/// The single running workout: drives the engine, Live Activity, sound, haptics and interruptions (TECH T4, T9).
@MainActor
@Observable
final class WorkoutController {
    private(set) var engine: WorkoutEngine?
    private(set) var timerName = ""
    /// Kept for the history record, so "Repeat" works after the timer is edited or deleted.
    private(set) var definition = TimerDefinition(blocks: [])
    private(set) var startedAt = Date.now
    let settings: AppSettings
    var colors: StepColors { settings.stepColors }

    private let clock = ContinuousClock()
    private let origin: ContinuousClock.Instant
    private var cueTask: Task<Void, Never>?
    private let liveActivity = LiveActivityManager()
    private let audio: WorkoutAudio

    init(settings: AppSettings) {
        self.settings = settings
        origin = clock.now
        audio = WorkoutAudio(settings: settings)
        audio.onInterruptionBegan = { [weak self] in self?.interrupted() }
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
        // Here, not in init: SwiftUI may build the App, and so a spare controller, more than once.
        WorkoutCommands.handler = { [weak self] command in
            switch command {
            case .togglePause: self?.togglePause()
            case .skip: self?.skip()
            }
        }
        WorkoutCommands.flush = { [weak self] in await self?.liveActivity.flush() }
        if settings.showOnLockScreen {
            liveActivity.start(timerName: name, state: activityState())
        }
        // Only matters while the app is in front (SPEC D7).
        UIApplication.shared.isIdleTimerDisabled = settings.keepScreenOn
        audio.begin()
        if let step = engine.currentStep { audio.stepStarted(step) }
        scheduleNextCue()
    }

    func pause() { mutate { $0.pause(at: $1) } }
    func resume() { mutate { $0.resume(at: $1) } }
    func togglePause() { engine?.phase == .paused ? resume() : pause() }
    func skip() { mutate { $0.skip(at: $1) }; announceStep() }
    func back() { mutate { $0.back(at: $1) }; announceStep() }
    func finish() { mutate { $0.finish(at: $1) }; audio.end() }

    /// Sound set sample from Settings.
    func previewSound(_ set: SoundSet) { audio.preview(set) }

    /// Audio may have been taken while the app was away.
    func appDidBecomeActive() { audio.resumeIfNeeded() }

    /// Closes the summary screen.
    func close() {
        cueTask?.cancel()
        engine = nil
        liveActivity.end()
        audio.end()
        UIApplication.shared.isIdleTimerDisabled = false
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
            UIApplication.shared.isIdleTimerDisabled = false
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
        // A frozen app wakes up late: stale signals are not played.
        let onTime = now - cue.time < 1
        if case .countdown(let left) = cue.kind, onTime { audio.countdown(left) }
        let transitions = engine.update(at: now)
        self.engine = engine
        if transitions.isEmpty {
            scheduleNextCue()
        } else {
            // The Lock Screen first: audio work must not hold it back.
            didChangeState()
        }
        if onTime, let last = transitions.last { announce(last) }
    }

    /// Pause on a call, Siri or alarm; no automatic resume (SPEC D6).
    private func interrupted() {
        guard settings.pauseOnInterruption, engine?.phase == .running else { return }
        pause()
    }

    /// A new step after Skip or Back, or the end when Skip passed the last one.
    private func announceStep() {
        guard let engine else { return }
        switch engine.phase {
        case .finished(.complete): audio.finished()
        case .running, .paused: if let step = engine.currentStep { audio.stepStarted(step) }
        default: break
        }
    }

    private func announce(_ transition: Transition) {
        switch transition {
        case .stepStarted: if let step = engine?.currentStep { audio.stepStarted(step) }
        case .finished: audio.finished()
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

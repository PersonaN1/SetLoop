import Foundation
import Testing
@testable import SetLoopCore

/// Work 10 / Rest 5 / Work 10.
private func engine() -> WorkoutEngine {
    WorkoutEngine(plan: TimerDefinition(blocks: [Block(steps: [step(10), step(5, .rest), step(10)])]).plan)
}

@Suite struct WorkoutEngineTests {
    @Test func runsToTheEndAndRecordsEveryStep() {
        var e = engine()
        e.start(at: 100)
        #expect(e.update(at: 109.9).isEmpty)
        #expect(e.update(at: 110) == [.stepStarted(1)])
        #expect(e.update(at: 125) == [.stepStarted(2), .finished])
        #expect(e.phase == .finished(.complete))
        #expect(e.log.map(\.outcome) == [.completed, .completed, .completed])
        #expect(e.activeTime(at: 200) == 25)
    }

    @Test func catchesUpAfterBeingFrozenInBackground() {
        var e = engine()
        e.start(at: 0)
        e.update(at: 12) // 2 s into rest
        #expect(e.currentIndex == 1)
        #expect(e.stepRemaining(at: 12) == 3)
    }

    @Test func pauseFreezesTime() {
        var e = engine()
        e.start(at: 0)
        e.pause(at: 4)
        #expect(e.stepRemaining(at: 1000) == 6)
        e.resume(at: 1000)
        #expect(e.stepRemaining(at: 1003) == 3)
        e.update(at: 1006)
        #expect(e.currentIndex == 1)
        #expect(e.activeTime(at: 1006) == 10)
    }

    @Test func skipMarksOnlyThatStep() {
        var e = engine()
        e.start(at: 0)
        e.skip(at: 3)
        #expect(e.currentIndex == 1)
        #expect(e.stepRemaining(at: 3) == 5)
        e.update(at: 30)
        #expect(e.log.map(\.outcome) == [.skipped, .completed, .completed])
        #expect(e.phase == .finished(.complete))
    }

    @Test func backRestartsOrGoesToPrevious() {
        var e = engine()
        e.start(at: 0)
        e.update(at: 13) // rest, 3 s in
        e.back(at: 13)
        #expect(e.currentIndex == 1)
        #expect(e.stepRemaining(at: 13) == 5)

        e.back(at: 14) // 1 s in → previous
        #expect(e.currentIndex == 0)
        #expect(e.stepRemaining(at: 14) == 10)
        #expect(e.log.isEmpty)
    }

    @Test func backOnFirstStepRestartsIt() {
        var e = engine()
        e.start(at: 0)
        e.back(at: 1)
        #expect(e.currentIndex == 0)
        #expect(e.stepRemaining(at: 1) == 10)
    }

    @Test func earlyFinishIsPartialAndDropsLaterSteps() {
        var e = engine()
        e.start(at: 0)
        e.update(at: 12)
        e.pause(at: 12)
        e.finish(at: 20)
        #expect(e.phase == .finished(.partial))
        #expect(e.log.map(\.outcome) == [.completed, .interrupted])
        #expect(e.activeTime(at: 20) == 12)
    }

    @Test func cuesCountDownThenEndStep() {
        var e = engine()
        e.start(at: 0)
        #expect(e.nextCue(at: 0) == Cue(time: 7, kind: .countdown(3)))
        #expect(e.nextCue(at: 7) == Cue(time: 8, kind: .countdown(2)))
        #expect(e.nextCue(at: 9.5) == Cue(time: 10, kind: .stepEnd))
        e.pause(at: 5)
        #expect(e.nextCue(at: 5) == nil)
    }

    @Test func shortStepsHaveNoCountdown() {
        var e = WorkoutEngine(plan: TimerDefinition(blocks: [Block(steps: [step(3)])]).plan)
        e.start(at: 0)
        #expect(e.nextCue(at: 0) == Cue(time: 3, kind: .stepEnd))
    }
}

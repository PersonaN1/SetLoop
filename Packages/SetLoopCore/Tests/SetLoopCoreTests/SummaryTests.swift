import Foundation
import Testing
@testable import SetLoopCore

@Suite struct SummaryTests {
    /// Prepare 10 / Work 20 / Rest 10 / Work 20 / Cooldown 30.
    private func engine() -> WorkoutEngine {
        let definition = TimerDefinition(
            prepare: step(10, .prepare),
            blocks: [Block(steps: [step(20), step(10, .rest)], repeats: 2)],
            cooldown: step(30, .cooldown),
            skipLastRest: true
        )
        return WorkoutEngine(plan: definition.plan)
    }

    @Test func completeWorkoutCountsEveryCategory() throws {
        var e = engine()
        e.start(at: 0)
        e.skip(at: 5) // prepare skipped
        e.update(at: 1000)
        let summary = try #require(WorkoutSummary(engine: e, at: 1000))
        #expect(summary.status == .complete)
        #expect(summary.totalSteps == 5) // the final rest is not in the plan
        #expect(summary.completedSteps == 4)
        #expect(summary.time(of: .work) == 40)
        #expect(summary.time(of: .rest) == 10)
        #expect(summary.time(of: .other) == 30)
        #expect(summary.duration == 85)
    }

    @Test func earlyFinishKeepsOnlyReachedSteps() throws {
        var e = engine()
        e.start(at: 0)
        e.pause(at: 15) // 5 s into the first work
        e.finish(at: 15)
        let summary = try #require(WorkoutSummary(engine: e, at: 15))
        #expect(summary.status == .partial)
        #expect(summary.steps.map(\.outcome) == [.completed, .interrupted])
        #expect(summary.completedSteps == 1)
        #expect(summary.time(of: .work) == 0)
        #expect(summary.duration == 15)
    }

    @Test func noSummaryWhileRunning() {
        var e = engine()
        e.start(at: 0)
        #expect(WorkoutSummary(engine: e, at: 1) == nil)
    }
}

@Suite struct StripLayoutTests {
    @Test func widthsFollowDurations() {
        let segments = StripLayout.segments(for: [10, 30], in: 101, spacing: 1)
        #expect(segments == [.init(x: 0, width: 25), .init(x: 26, width: 75)])
    }

    @Test func shortStepsGetMinimumWidth() {
        let segments = StripLayout.segments(for: [1, 1000], in: 101, minWidth: 3, spacing: 1)
        #expect(segments[0].width == 3)
        #expect(abs(segments[1].width - 97) < 0.0001)
        #expect(segments[1].x == 4)
    }

    @Test func tooManyStepsArePackedWithoutGaps() {
        let segments = StripLayout.segments(for: Array(repeating: 5, count: 100), in: 200, minWidth: 3, spacing: 1)
        #expect(segments.count == 100)
        #expect(segments[1].x == 2)
        #expect(abs(segments.last!.x + segments.last!.width - 200) < 0.0001)
    }

    @Test func emptyInput() {
        #expect(StripLayout.segments(for: [], in: 100).isEmpty)
    }
}

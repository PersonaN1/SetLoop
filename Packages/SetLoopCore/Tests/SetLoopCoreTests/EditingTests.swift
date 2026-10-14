import Foundation
import Testing
@testable import SetLoopCore

private func step(_ name: String, _ type: StepType = .workA, _ duration: Int = 10) -> Step {
    Step(name: name, duration: duration, type: type)
}

@Suite struct MergeTests {
    let a = step("A"), b = step("B", .rest), c = step("C"), d = step("D", .rest)

    @Test func middleStepsBecomeLoopedBlock() throws {
        var definition = TimerDefinition(blocks: [Block(steps: [a, b, c, d], repeats: 1)])
        try definition.mergeIntoBlock(stepIDs: [b.id, c.id])
        #expect(definition.blocks.map { $0.steps.map(\.name) } == [["A"], ["B", "C"], ["D"]])
        #expect(definition.blocks.map(\.repeats) == [1, 2, 1])
    }

    @Test func leadingStepsSplitOnce() throws {
        var definition = TimerDefinition(blocks: [Block(steps: [a, b, c], repeats: 3)])
        try definition.mergeIntoBlock(stepIDs: [a.id, b.id])
        #expect(definition.blocks.map { $0.steps.map(\.name) } == [["A", "B"], ["C"]])
        #expect(definition.blocks.map(\.repeats) == [2, 3])
    }

    @Test func rejectsGapsOtherBlocksAndWholeBlock() {
        var definition = TimerDefinition(blocks: [Block(steps: [a, b, c]), Block(steps: [d])])
        #expect(throws: TimerDefinition.MergeError.notContiguous) { try definition.mergeIntoBlock(stepIDs: [a.id, c.id]) }
        #expect(throws: TimerDefinition.MergeError.notContiguous) { try definition.mergeIntoBlock(stepIDs: [c.id, d.id]) }
        #expect(throws: TimerDefinition.MergeError.notContiguous) { try definition.mergeIntoBlock(stepIDs: []) }
        #expect(throws: TimerDefinition.MergeError.wholeBlock) { try definition.mergeIntoBlock(stepIDs: [d.id]) }
    }

    @Test func respectsBlockLimit() {
        let filler = (0..<9).map { _ in Block(steps: [step("x")]) }
        var definition = TimerDefinition(blocks: filler + [Block(steps: [a, b, c])])
        #expect(throws: TimerDefinition.MergeError.tooManyBlocks) { try definition.mergeIntoBlock(stepIDs: [b.id]) }
        #expect(definition.blocks.count == 10)
    }

    @Test func nextStepAlternates() {
        let names: (StepType) -> String = { $0 == .rest ? "Rest" : "Work" }
        #expect(Step.next(after: nil, names: names).type == .workA)
        #expect(Step.next(after: step("W", .workB), names: names).type == .rest)
        #expect(Step.next(after: step("R", .rest), names: names).type == .workA)
    }
}

@Suite struct PreviewStripTests {
    let work = step("W", .workA, 20), rest = step("R", .rest, 10)

    @Test func smallWorkoutShowsEverything() {
        let strip = PreviewStrip(TimerDefinition(prepare: step("P", .prepare), blocks: [Block(steps: [work, rest], repeats: 8)]))
        #expect(strip.level == .workout)
        #expect(strip.groups.count == 1)
        #expect(strip.groups[0].segments.count == 17)
    }

    @Test func manySetsShowOneSet() {
        let strip = PreviewStrip(TimerDefinition(blocks: [Block(steps: [work, rest], repeats: 8)], sets: 4))
        #expect(strip.level == .oneSet)
        #expect(strip.groups == [PreviewStrip.Group(segments: Array(repeating: [.init(type: .workA, duration: 20), .init(type: .rest, duration: 10)], count: 8).flatMap { $0 }, repeats: 4)])
    }

    @Test func longBlocksShowOneCycleEach() {
        let strip = PreviewStrip(TimerDefinition(blocks: [Block(steps: [work, rest], repeats: 20), Block(steps: [rest], repeats: 3)]))
        #expect(strip.level == .oneCycle)
        #expect(strip.groups.map(\.repeats) == [20, 3])
        #expect(strip.equalGroupWidths)
    }

    @Test func hugeBlocksCollapse() {
        let long = step("L", .workB, 60)
        let steps = (0..<20).map { _ in work } + [long]
        let strip = PreviewStrip(TimerDefinition(blocks: [Block(steps: steps, repeats: 2), Block(steps: [rest, work, rest, work, rest])]))
        #expect(strip.level == .blocks)
        #expect(strip.groups[0].segments == [.init(type: .workB, duration: 460)])
        #expect(strip.groups[1].segments.count == 1)
    }
}

@Suite struct TimerNamingTests {
    @Test func freeNameStaysAsIs() {
        #expect(TimerNaming.unique("New Timer", among: ["Tabata"]) == "New Timer")
    }

    @Test func takenNameGetsNextNumber() {
        #expect(TimerNaming.unique("New Timer", among: ["New Timer"]) == "New Timer (2)")
        #expect(TimerNaming.unique("New Timer", among: ["New Timer", "New Timer (2)"]) == "New Timer (3)")
    }

    @Test func fillsTheFirstGap() {
        #expect(TimerNaming.unique("A", among: ["A", "A (3)"]) == "A (2)")
    }

    @Test func copyOfNumberedNameContinuesTheSeries() {
        #expect(TimerNaming.unique("A (2)", among: ["A", "A (2)"]) == "A (3)")
    }

    @Test func otherParenthesesAreKept() {
        #expect(TimerNaming.unique("Run (easy)", among: ["Run (easy)"]) == "Run (easy) (2)")
        #expect(TimerNaming.unique("Set (1)", among: ["Set (1)"]) == "Set (1) (2)")
    }
}

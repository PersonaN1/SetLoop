import Foundation
import Testing
@testable import SetLoopCore

let names = Presets.Names(prepare: "Prepare", work: "Work", rest: "Rest", restBetweenSets: "Set rest",
                          tabata: "Tabata", simpleInterval: "Simple", twoBlocks: "Two blocks")

func step(_ duration: Int, _ type: StepType = .workA) -> Step {
    Step(name: type.rawValue, duration: duration, type: type)
}

@Suite struct WorkoutPlanTests {
    @Test func presetTotalsMatchDesign() {
        let presets = Presets.all(names).map(\.definition.plan)
        #expect(presets[0].totalDuration == 250)
        #expect(presets[1].totalDuration == 600)

        let example = presets[2]
        #expect(example.totalDuration == 292)
        #expect(example.steps.count == 33)
        #expect(example.duration(of: .work) == 105)
        #expect(example.duration(of: .rest) == 177)
        #expect(example.duration(of: .other) == 10)
    }

    @Test func positionsCountSetsBlocksAndCycles() {
        let plan = Presets.all(names)[2].definition.plan
        #expect(plan.steps[0].position.set == nil)
        #expect(plan.steps[1].position == .init(set: 1, setCount: 3, block: 1, blockCount: 2, cycle: 1, cycleCount: 2))
        #expect(plan.steps[5].position == .init(set: 1, setCount: 3, block: 2, blockCount: 2, cycle: 1, cycleCount: 3))
        #expect(plan.steps[11].position.set == nil) // rest between sets
        #expect(plan.steps.map(\.index) == Array(0..<33))
    }

    @Test func skipLastRestRemovesOnlyFinalRest() {
        var definition = TimerDefinition(
            blocks: [Block(steps: [step(20), step(10, .rest)], repeats: 2)],
            sets: 2,
            restBetweenSets: step(60, .rest)
        )
        #expect(definition.plan.steps.count == 9)

        definition.skipLastRest = true
        let plan = definition.plan
        #expect(plan.steps.count == 8)
        #expect(plan.steps.last?.type == .workA)
        #expect(plan.steps.filter { $0.duration == 60 }.count == 1) // rest between sets stays
    }

    @Test func skipLastRestKeepsCooldownAndIgnoresWorkEnding() {
        let withCooldown = TimerDefinition(
            blocks: [Block(steps: [step(20), step(10, .rest)])],
            cooldown: step(30, .cooldown),
            skipLastRest: true
        ).plan
        #expect(withCooldown.steps.map(\.type) == [.workA, .cooldown])

        let workLast = TimerDefinition(blocks: [Block(steps: [step(10, .rest), step(20)])], skipLastRest: true).plan
        #expect(workLast.steps.count == 2)
    }

    @Test func validationLimits() {
        #expect(throws: TimerDefinition.ValidationError.noSteps) {
            try TimerDefinition(blocks: [Block(steps: [])]).validate()
        }
        #expect(throws: TimerDefinition.ValidationError.repeatsOutOfRange) {
            try TimerDefinition(blocks: [Block(steps: [step(5)], repeats: 100)]).validate()
        }
        let tooLong = step(6000)
        #expect(throws: TimerDefinition.ValidationError.stepDurationOutOfRange(stepID: tooLong.id)) {
            try TimerDefinition(blocks: [Block(steps: [tooLong])]).validate()
        }
        #expect(throws: TimerDefinition.ValidationError.tooManyBlocks) {
            try TimerDefinition(blocks: Array(repeating: Block(steps: [step(5)]), count: 11)).validate()
        }
        #expect(throws: TimerDefinition.ValidationError.emptyPlan) {
            try TimerDefinition(blocks: [Block(steps: [step(5, .rest)])], skipLastRest: true).validate()
        }
        // Prepare still gives the plan something to run.
        #expect((try? TimerDefinition(prepare: step(5, .prepare), blocks: [Block(steps: [step(5, .rest)])],
                                      skipLastRest: true).validate()) != nil)
    }

    @Test func definitionRoundTripsThroughJSON() throws {
        let definition = Presets.all(names)[2].definition
        let data = try JSONEncoder().encode(definition)
        #expect(try JSONDecoder().decode(TimerDefinition.self, from: data) == definition)
    }
}

@Suite struct PaletteTests {
    @Test func lightenedRedMatchesDesignIntent() {
        let light = RGB(0xE8452C).lightened
        #expect(light.hex >> 16 == 0xFF)
        #expect(light.green > RGB(0xE8452C).green)
    }

    @Test func restColorIsBlockedForWork() {
        let colors = StepColors.default
        #expect(!colors.isAllowed(RGB(0x1E8E52), for: .workB))
        #expect(!colors.isAllowed(RGB(0xE8452C), for: .rest))
        #expect(colors.isAllowed(RGB(0x2F6BDB), for: .workB))
        #expect(colors.isAllowed(RGB(0x1E8E52), for: .prepare))
    }
}

@Suite struct PlanArithmeticTests {
    private func expectMatchesPlan(_ definition: TimerDefinition, sourceLocation: SourceLocation = #_sourceLocation) {
        let plan = definition.plan
        #expect(definition.stepCount == plan.steps.count, sourceLocation: sourceLocation)
        #expect(definition.totalDuration == plan.totalDuration, sourceLocation: sourceLocation)
        for category in [StepType.Category.work, .rest, .other] {
            #expect(definition.duration(of: category) == plan.duration(of: category), sourceLocation: sourceLocation)
        }
    }

    @Test func presetsMatchPlan() {
        for preset in Presets.all(names) {
            expectMatchesPlan(preset.definition)
            var skipping = preset.definition
            skipping.skipLastRest.toggle()
            expectMatchesPlan(skipping)
        }
    }

    @Test func edgeCasesMatchPlan() {
        let rest = step(7, .rest)
        let cases = [
            TimerDefinition(blocks: []),
            TimerDefinition(blocks: [Block(steps: [])]),
            TimerDefinition(blocks: [Block(steps: [rest])], skipLastRest: true),
            TimerDefinition(prepare: step(5, .prepare), blocks: [Block(steps: [rest])], skipLastRest: true),
            TimerDefinition(blocks: [Block(steps: [step(20), rest], repeats: 4)], sets: 3,
                            restBetweenSets: step(60, .rest), cooldown: step(30, .cooldown), skipLastRest: true),
            // The last non-empty block decides; an empty block after it doesn't.
            TimerDefinition(blocks: [Block(steps: [step(20), rest], repeats: 2), Block(steps: [])], sets: 2,
                            skipLastRest: true),
            TimerDefinition(blocks: [Block(steps: [rest, step(20)])], sets: 2, restBetweenSets: step(60, .rest),
                            skipLastRest: true),
            TimerDefinition(blocks: [], sets: 3, restBetweenSets: step(60, .rest), skipLastRest: true),
            TimerDefinition(blocks: [Block(steps: [step(20, .workB), step(15, .workC)], repeats: 99)], sets: 99),
        ]
        for definition in cases { expectMatchesPlan(definition) }
    }

    @Test func emptyPlanIsCounted() {
        #expect(TimerDefinition(blocks: [Block(steps: [step(5, .rest)])], skipLastRest: true).stepCount == 0)
    }
}

@Suite struct StepColorsCodingTests {
    @Test func roundTripsAsKeyedObject() throws {
        var colors = StepColors.default
        colors.colors[.workB] = RGB(0x2F6BDB)
        let data = try JSONEncoder().encode(colors)
        let json = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        #expect(json["colors"] is [String: Any])
        #expect(try JSONDecoder().decode(StepColors.self, from: data) == colors)
    }

    @Test func readsKeyedObjectSkippingUnknownTypes() throws {
        let json = #"{"colors": {"workA": {"hex": 3107803}, "workD": {"hex": 1}}}"#
        let colors = try JSONDecoder().decode(StepColors.self, from: Data(json.utf8))
        #expect(colors.colors == [.workA: RGB(0x2F6BDB)])
    }

    @Test func readsLegacyFlatArraySkippingUnknownTypes() throws {
        let json = #"{"colors": ["rest", {"hex": 3107803}, "workD", {"hex": 1}, "workA", {"hex": 15222060}]}"#
        let colors = try JSONDecoder().decode(StepColors.self, from: Data(json.utf8))
        #expect(colors.colors == [.rest: RGB(0x2F6BDB), .workA: RGB(0xE8452C)])
    }
}

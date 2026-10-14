import Foundation

/// One step of the flattened plan, with its position in the structure.
public struct PlannedStep: Hashable, Sendable {
    public struct Position: Hashable, Sendable {
        /// 1-based; nil for prepare / cooldown / rest between sets.
        public var set: Int?
        public var setCount: Int
        public var block: Int?
        public var blockCount: Int
        public var cycle: Int?
        public var cycleCount: Int?
    }

    public var index: Int
    public var step: Step
    public var position: Position

    public var duration: Int { step.duration }
    public var type: StepType { step.type }
}

/// Linear sequence of steps the engine runs through.
public struct WorkoutPlan: Hashable, Sendable {
    public var steps: [PlannedStep]

    public init(_ definition: TimerDefinition) {
        var result: [PlannedStep] = []
        let setCount = max(definition.sets, 1)
        let blockCount = definition.blocks.count

        func append(_ step: Step, _ position: PlannedStep.Position) {
            result.append(PlannedStep(index: result.count, step: step, position: position))
        }
        let outside = PlannedStep.Position(set: nil, setCount: setCount, block: nil, blockCount: blockCount)

        if let prepare = definition.prepare { append(prepare, outside) }
        for set in 1...setCount {
            for (blockIndex, block) in definition.blocks.enumerated() {
                let cycles = max(block.repeats, 1)
                for cycle in 1...cycles {
                    for step in block.steps {
                        append(step, .init(
                            set: set, setCount: setCount,
                            block: blockIndex + 1, blockCount: blockCount,
                            cycle: cycle, cycleCount: cycles
                        ))
                    }
                }
            }
            if set < setCount, let rest = definition.restBetweenSets {
                append(rest, outside)
            }
        }
        // The final rest is not part of the plan at all: neither skipped nor counted (SPEC D10, D18).
        if definition.skipLastRest, let last = result.last, last.type == .rest, last.position.set != nil {
            result.removeLast()
        }
        if let cooldown = definition.cooldown { append(cooldown, outside) }

        steps = result
    }

    public var totalDuration: Int { steps.reduce(0) { $0 + $1.duration } }

    public func duration(of category: StepType.Category) -> Int {
        steps.filter { $0.type.category == category }.reduce(0) { $0 + $1.duration }
    }
}

extension TimerDefinition {
    public var plan: WorkoutPlan { WorkoutPlan(self) }
}

// MARK: - Plan arithmetic

/// Plan totals computed from the structure: limits allow millions of steps, too many to build for a list row.
extension TimerDefinition {
    /// The plan's final set step, when `skipLastRest` drops it.
    private var droppedLastRest: Step? {
        guard skipLastRest, let last = blocks.last(where: { !$0.steps.isEmpty })?.steps.last,
              last.type == .rest else { return nil }
        return last
    }

    /// Sums `value` over the plan's steps without building it.
    private func planSum(_ value: (Step) -> Int) -> Int {
        let setCount = max(sets, 1)
        let perSet = blocks.reduce(0) { sum, block in
            sum + block.steps.reduce(0) { $0 + value($1) } * max(block.repeats, 1)
        }
        var total = perSet * setCount
        if let rest = restBetweenSets { total += value(rest) * (setCount - 1) }
        if let dropped = droppedLastRest { total -= value(dropped) }
        if let prepare { total += value(prepare) }
        if let cooldown { total += value(cooldown) }
        return total
    }

    /// `plan.steps.count`.
    public var stepCount: Int { planSum { _ in 1 } }

    /// `plan.totalDuration`.
    public var totalDuration: Int { planSum(\.duration) }

    /// `plan.duration(of:)`.
    public func duration(of category: StepType.Category) -> Int {
        planSum { $0.type.category == category ? $0.duration : 0 }
    }
}

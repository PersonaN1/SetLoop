import Foundation

/// Step type. Defines color, sound and how the step is counted in history (SPEC D2, DESIGN V2).
public enum StepType: String, Codable, CaseIterable, Sendable {
    case prepare
    case workA
    case workB
    case workC
    case rest
    case cooldown

    public enum Category: Sendable {
        case work, rest, other
    }

    public var category: Category {
        switch self {
        case .workA, .workB, .workC: .work
        case .rest: .rest
        case .prepare, .cooldown: .other
        }
    }
}

public struct Step: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var name: String
    /// Seconds, 1...5999 (SPEC D18).
    public var duration: Int
    public var type: StepType

    public init(id: UUID = UUID(), name: String, duration: Int, type: StepType) {
        self.id = id
        self.name = name
        self.duration = duration
        self.type = type
    }
}

public struct Block: Codable, Hashable, Identifiable, Sendable {
    public var id: UUID
    public var steps: [Step]
    /// Cycles, 1...99.
    public var repeats: Int

    public init(id: UUID = UUID(), steps: [Step], repeats: Int = 1) {
        self.id = id
        self.steps = steps
        self.repeats = repeats
    }
}

/// Full timer structure, stored as one JSON value (TECH T5).
/// Timer = [Prepare] → Sets ×N (rest between) → Blocks ×M → Steps → [Cooldown] (SPEC D2).
public struct TimerDefinition: Codable, Hashable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var prepare: Step?
    public var blocks: [Block]
    /// 1...99.
    public var sets: Int
    /// Rest between sets; nil or used only when `sets > 1`.
    public var restBetweenSets: Step?
    public var cooldown: Step?
    /// Removes only the final rest at the very end of the workout (SPEC D18).
    public var skipLastRest: Bool

    public init(
        prepare: Step? = nil,
        blocks: [Block],
        sets: Int = 1,
        restBetweenSets: Step? = nil,
        cooldown: Step? = nil,
        skipLastRest: Bool = false
    ) {
        self.version = Self.currentVersion
        self.prepare = prepare
        self.blocks = blocks
        self.sets = sets
        self.restBetweenSets = restBetweenSets
        self.cooldown = cooldown
        self.skipLastRest = skipLastRest
    }
}

public enum Limits {
    public static let maxTimers = 30
    public static let maxBlocks = 10
    public static let maxStepsPerBlock = 30
    public static let stepDuration = 1...5999
    public static let repeats = 1...99
}

extension TimerDefinition {
    public enum ValidationError: Error, Equatable, Sendable {
        case noSteps
        case tooManyBlocks
        case tooManyStepsInBlock(blockIndex: Int)
        case stepDurationOutOfRange(stepID: UUID)
        case repeatsOutOfRange
    }

    public func validate() throws(ValidationError) {
        guard blocks.contains(where: { !$0.steps.isEmpty }) else { throw .noSteps }
        guard blocks.count <= Limits.maxBlocks else { throw .tooManyBlocks }
        guard Limits.repeats.contains(sets) else { throw .repeatsOutOfRange }
        for (index, block) in blocks.enumerated() {
            guard block.steps.count <= Limits.maxStepsPerBlock else {
                throw .tooManyStepsInBlock(blockIndex: index)
            }
            guard Limits.repeats.contains(block.repeats) else { throw .repeatsOutOfRange }
        }
        let allSteps = blocks.flatMap(\.steps) + [prepare, restBetweenSets, cooldown].compactMap { $0 }
        if let bad = allSteps.first(where: { !Limits.stepDuration.contains($0.duration) }) {
            throw .stepDurationOutOfRange(stepID: bad.id)
        }
    }
}

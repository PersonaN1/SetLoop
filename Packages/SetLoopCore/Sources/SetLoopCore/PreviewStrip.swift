import Foundation

/// Colored preview of a timer's structure, with the level of detail picked by a segment threshold (DESIGN V4).
public struct PreviewStrip: Equatable, Sendable {
    public struct Segment: Equatable, Sendable {
        public var type: StepType
        public var duration: Int
    }

    /// A run of segments drawn together; `repeats > 1` is shown as "×N" above it.
    public struct Group: Equatable, Sendable {
        public var segments: [Segment]
        public var repeats: Int
    }

    public enum Level: Equatable, Sendable {
        case workout, oneSet, oneCycle, blocks
    }

    /// Not a user setting; tune on a device (DESIGN V4).
    public static let threshold = 24

    public var level: Level
    public var groups: [Group]
    /// Groups share the width equally on levels 3–4; otherwise widths follow durations.
    public var equalGroupWidths: Bool { level == .oneCycle || level == .blocks }

    public init(_ definition: TimerDefinition, threshold: Int = Self.threshold) {
        let plan = definition.plan
        let sets = max(definition.sets, 1)
        let oneSet = definition.blocks.flatMap { block in
            Array(repeating: block.steps, count: max(block.repeats, 1)).flatMap { $0 }
        }
        let cycleSteps = definition.blocks.reduce(0) { $0 + $1.steps.count }

        if plan.steps.count <= threshold {
            level = .workout
            groups = [Group(segments: plan.steps.map { Segment(type: $0.type, duration: $0.duration) }, repeats: 1)]
        } else if sets > 1, oneSet.count <= threshold {
            level = .oneSet
            groups = [Group(segments: oneSet.map(Segment.init), repeats: sets)]
        } else if cycleSteps <= threshold {
            level = .oneCycle
            groups = definition.blocks.map { Group(segments: $0.steps.map(Segment.init), repeats: max($0.repeats, 1)) }
        } else {
            level = .blocks
            groups = definition.blocks.map { block in
                let longest = block.steps.max { $0.duration < $1.duration }
                let total = block.steps.reduce(0) { $0 + $1.duration }
                return Group(segments: [Segment(type: longest?.type ?? .workA, duration: total)],
                             repeats: max(block.repeats, 1))
            }
        }
    }
}

extension PreviewStrip.Segment {
    init(_ step: Step) { self.init(type: step.type, duration: step.duration) }
}

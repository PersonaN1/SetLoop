import Foundation

/// Editing operations used by the timer editor (TECH T4). The editor works on a copy (TECH T5).
extension TimerDefinition {
    public enum MergeError: Error, Equatable, Sendable {
        /// Steps come from different blocks, are not neighbors, or nothing is selected.
        case notContiguous
        /// The selection already is a whole block.
        case wholeBlock
        case tooManyBlocks
    }

    /// "Merge into Block" (SPEC D2): neighboring steps of one block become their own block, looped twice.
    /// Steps before and after the selection stay in blocks of their own with the old repeat count.
    public mutating func mergeIntoBlock(stepIDs: Set<UUID>) throws(MergeError) {
        guard let blockIndex = blocks.firstIndex(where: { $0.steps.contains { stepIDs.contains($0.id) } }) else {
            throw .notContiguous
        }
        let block = blocks[blockIndex]
        let positions = block.steps.indices.filter { stepIDs.contains(block.steps[$0].id) }
        guard positions.count == stepIDs.count,
              let first = positions.first, let last = positions.last,
              last - first + 1 == positions.count
        else { throw .notContiguous }
        guard positions.count < block.steps.count else { throw .wholeBlock }

        var replacement: [Block] = []
        if first > 0 {
            replacement.append(Block(steps: Array(block.steps[..<first]), repeats: block.repeats))
        }
        replacement.append(Block(steps: Array(block.steps[first...last]), repeats: 2))
        if last < block.steps.count - 1 {
            replacement.append(Block(steps: Array(block.steps[(last + 1)...]), repeats: block.repeats))
        }
        // The first piece stays the original block, so the list keeps its identity in place.
        replacement[0].id = block.id
        guard blocks.count - 1 + replacement.count <= Limits.maxBlocks else { throw .tooManyBlocks }
        blocks.replaceSubrange(blockIndex...blockIndex, with: replacement)
    }

    /// Drops blocks without steps, e.g. after the user deleted every step of one.
    public mutating func removeEmptyBlocks() {
        blocks.removeAll { $0.steps.isEmpty }
    }
}

extension Step {
    /// A sensible next step: rest after work, work after anything else.
    public static func next(after previous: Step?, names: (StepType) -> String) -> Step {
        let type: StepType = previous?.type.category == .work ? .rest : .workA
        return Step(name: names(type), duration: type == .rest ? 10 : 20, type: type)
    }
}

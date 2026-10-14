import Foundation

/// Lays out a colored strip of steps: widths follow durations, each segment at least `minWidth` (DESIGN V4).
public enum StripLayout {
    public struct Segment: Equatable, Sendable {
        public var x: Double
        public var width: Double
    }

    /// When the segments cannot all get `minWidth` and the gaps, they are packed proportionally without gaps.
    public static func segments(
        for durations: [Int], in width: Double, minWidth: Double = 3, spacing: Double = 1
    ) -> [Segment] {
        guard !durations.isEmpty, width > 0 else { return [] }
        let weights = durations.map { Double(max($0, 0)) }
        let count = Double(durations.count)
        let fits = width - spacing * (count - 1) >= minWidth * count

        let gap = fits ? spacing : 0
        let available = width - gap * (count - 1)
        let widths = fits
            ? clamped(weights, to: available, minWidth: minWidth)
            : proportional(weights, to: available)

        var x = 0.0
        return widths.map { w in
            defer { x += w + gap }
            return Segment(x: x, width: w)
        }
    }

    private static func proportional(_ weights: [Double], to width: Double) -> [Double] {
        let total = weights.reduce(0, +)
        guard total > 0 else { return weights.map { _ in width / Double(weights.count) } }
        return weights.map { width * $0 / total }
    }

    /// Pins too-narrow segments to `minWidth` and shares the rest among the others, until nothing changes.
    private static func clamped(_ weights: [Double], to width: Double, minWidth: Double) -> [Double] {
        var pinned = Set<Int>()
        while true {
            let free = weights.indices.filter { !pinned.contains($0) }
            let shared = proportional(free.map { weights[$0] }, to: width - minWidth * Double(pinned.count))
            let narrow = zip(free, shared).filter { $0.1 < minWidth }.map(\.0)
            if narrow.isEmpty {
                var result = Array(repeating: minWidth, count: weights.count)
                for (index, w) in zip(free, shared) { result[index] = w }
                return result
            }
            pinned.formUnion(narrow)
        }
    }
}

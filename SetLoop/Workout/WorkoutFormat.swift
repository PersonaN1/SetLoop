import Foundation
import SetLoopCore

enum WorkoutFormat {
    /// 0:05, 4:52, 12:00.
    static func time(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded(.up))
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Workout length: 4:52, 1:05:30.
    static func duration(_ seconds: Int) -> String {
        seconds >= 3600
            ? String(format: "%d:%02d:%02d", seconds / 3600, seconds / 60 % 60, seconds % 60)
            : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    /// Totals in words: "1 hr, 20 min", "45 min".
    static func longDuration(_ seconds: Int) -> String {
        Duration.seconds(seconds).formatted(.units(allowed: [.hours, .minutes], width: .abbreviated))
    }

    /// "Cycle 2/3 · Set 1/4"; parts that don't apply are omitted.
    static func position(_ position: PlannedStep.Position) -> String {
        var parts: [String] = []
        if let cycle = position.cycle, let count = position.cycleCount, count > 1 {
            parts.append(String(localized: "Cycle \(cycle)/\(count)"))
        }
        if let set = position.set, position.setCount > 1 {
            parts.append(String(localized: "Set \(set)/\(position.setCount)"))
        }
        return parts.joined(separator: " · ")
    }

    static func next(_ step: PlannedStep) -> String {
        String(localized: "Next: \(step.step.name) \(time(TimeInterval(step.duration)))")
    }
}

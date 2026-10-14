import Foundation
import SetLoopCore
import SwiftData

/// A finished workout saved from the summary screen (SPEC D10). Independent of the timer it came from.
@Model
final class WorkoutRecord {
    var id: UUID = UUID()
    var startedAt: Date = Date.now
    var name: String = ""
    var note: String = ""
    /// Active time without pauses, seconds.
    var duration: Int = 0
    var statusRaw: String = WorkoutStatus.complete.rawValue
    var workTime: Int = 0
    var restTime: Int = 0
    var otherTime: Int = 0
    var completedSteps: Int = 0
    var totalSteps: Int = 0
    var stepsData: Data = Data()

    init(name: String, startedAt: Date, duration: Int, status: WorkoutStatus, totalSteps: Int, steps: [StepRecord]) {
        self.name = name
        self.startedAt = startedAt
        self.duration = duration
        self.statusRaw = status.rawValue
        self.totalSteps = totalSteps
        self.steps = steps
    }

    var status: WorkoutStatus { WorkoutStatus(rawValue: statusRaw) ?? .complete }

    var steps: [StepRecord] {
        get { (try? JSONDecoder().decode([StepRecord].self, from: stepsData)) ?? [] }
        set {
            stepsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            completedSteps = newValue.filter { $0.outcome == .completed }.count
            func time(_ category: StepType.Category) -> Int {
                newValue.filter { $0.outcome == .completed && $0.step.type.category == category }
                    .reduce(0) { $0 + $1.step.duration }
            }
            workTime = time(.work)
            restTime = time(.rest)
            otherTime = time(.other)
        }
    }
}

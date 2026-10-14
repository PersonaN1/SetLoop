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
    /// Snapshot of the timer structure for "Repeat"; editing or deleting the timer does not touch it.
    var definitionData: Data = Data()

    init(name: String, note: String, startedAt: Date, summary: WorkoutSummary, definition: TimerDefinition) {
        self.name = name
        self.note = note
        self.startedAt = startedAt
        self.duration = summary.duration
        self.statusRaw = summary.status.rawValue
        self.totalSteps = summary.totalSteps
        self.steps = summary.steps
        self.definitionData = (try? JSONEncoder().encode(definition)) ?? Data()
    }

    var status: WorkoutStatus { WorkoutStatus(rawValue: statusRaw) ?? .complete }

    var definition: TimerDefinition? { try? JSONDecoder().decode(TimerDefinition.self, from: definitionData) }

    var steps: [StepRecord] {
        get { (try? JSONDecoder().decode([StepRecord].self, from: stepsData)) ?? [] }
        set {
            stepsData = (try? JSONEncoder().encode(newValue)) ?? Data()
            completedSteps = newValue.completedCount
            workTime = newValue.time(of: .work)
            restTime = newValue.time(of: .rest)
            otherTime = newValue.time(of: .other)
        }
    }
}

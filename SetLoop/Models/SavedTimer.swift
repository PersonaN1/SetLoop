import Foundation
import SetLoopCore
import SwiftData

/// A saved timer: list fields + the whole structure as one JSON value (TECH T5).
/// Every property has a default and there are no unique constraints, so CloudKit sync can be enabled later.
@Model
final class SavedTimer {
    var id: UUID = UUID()
    var name: String = ""
    var sortIndex: Int = 0
    var createdAt: Date = Date.now
    var updatedAt: Date = Date.now
    var totalDuration: Int = 0
    var definitionData: Data = Data()

    init(name: String, definition: TimerDefinition, sortIndex: Int) {
        self.name = name
        self.sortIndex = sortIndex
        self.definition = definition
    }

    var definition: TimerDefinition {
        get { (try? JSONDecoder().decode(TimerDefinition.self, from: definitionData)) ?? TimerDefinition(blocks: []) }
        set {
            definitionData = (try? JSONEncoder().encode(newValue)) ?? Data()
            totalDuration = newValue.plan.totalDuration
            updatedAt = .now
        }
    }
}

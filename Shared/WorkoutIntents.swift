import AppIntents

/// Lock Screen and Dynamic Island buttons (DESIGN V10, TECH T10).
///
/// Compiled into the app and the widget: the widget only shows the buttons, while iOS runs
/// `perform()` in the app's process, where `WorkoutCommands.handler` reaches the running workout.
enum WorkoutCommand: Sendable {
    case togglePause, skip
}

@MainActor
enum WorkoutCommands {
    /// Set by the workout controller; nil in the widget and when no workout runs.
    static var handler: ((WorkoutCommand) -> Void)?
}

struct TogglePauseIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Pause or Resume"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        WorkoutCommands.handler?(.togglePause)
        return .result()
    }
}

struct SkipStepIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Step"
    static let isDiscoverable = false

    @MainActor
    func perform() async throws -> some IntentResult {
        WorkoutCommands.handler?(.skip)
        return .result()
    }
}

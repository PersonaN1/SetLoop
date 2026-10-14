import AppIntents
import SetLoopCore
import SwiftData

/// App Shortcuts for Siri, Spotlight, Shortcuts and the Action button (SPEC D15, TECH T11).
/// App target only: unlike the Live Activity buttons, these reach `AppModel` directly.
struct SetLoopShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartTimerIntent(),
            phrases: [
                "Start \(\.$timer) in \(.applicationName)",
                "Start a timer in \(.applicationName)",
                "Start \(.applicationName)",
            ],
            shortTitle: "Start Timer",
            systemImageName: "play.fill"
        )
        AppShortcut(
            intent: PauseWorkoutIntent(),
            phrases: [
                "Pause \(.applicationName)",
                "Pause the workout in \(.applicationName)",
            ],
            shortTitle: "Pause",
            systemImageName: "pause.fill"
        )
        AppShortcut(
            intent: ResumeWorkoutIntent(),
            phrases: [
                "Resume \(.applicationName)",
                "Resume the workout in \(.applicationName)",
            ],
            shortTitle: "Resume",
            systemImageName: "play.fill"
        )
    }
}

/// A saved timer as Siri and Shortcuts see it.
struct TimerEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Timer"
    static let defaultQuery = TimerQuery()

    let id: UUID
    let name: String
    let duration: Int

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)", subtitle: "\(WorkoutFormat.duration(duration))")
    }

    init(_ timer: SavedTimer) {
        id = timer.id
        name = timer.name
        duration = timer.totalDuration
    }
}

struct TimerQuery: EntityStringQuery {
    @MainActor
    func entities(for identifiers: [TimerEntity.ID]) async throws -> [TimerEntity] {
        let ids = Set(identifiers)
        return Self.timers().filter { ids.contains($0.id) }.map(TimerEntity.init)
    }

    @MainActor
    func entities(matching string: String) async throws -> [TimerEntity] {
        Self.timers().filter { $0.name.localizedStandardContains(string) }.map(TimerEntity.init)
    }

    @MainActor
    func suggestedEntities() async throws -> [TimerEntity] {
        Self.timers().map(TimerEntity.init)
    }

    /// In list order.
    @MainActor
    static func timers() -> [SavedTimer] {
        let descriptor = FetchDescriptor<SavedTimer>(sortBy: [SortDescriptor(\.sortIndex)])
        return (try? AppModel.container.mainContext.fetch(descriptor)) ?? []
    }
}

struct StartTimerIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Timer"
    static let description = IntentDescription("Starts a workout with the chosen timer.")
    /// The workout screen, sound and Live Activity need the app in front.
    static let openAppWhenRun = true

    @Parameter(title: "Timer")
    var timer: TimerEntity

    static var parameterSummary: some ParameterSummary {
        Summary("Start \(\.$timer)")
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        guard let saved = TimerQuery.timers().first(where: { $0.id == timer.id }) else {
            throw ShortcutError.timerNotFound
        }
        guard !AppModel.workout.isPresented else { throw ShortcutError.workoutRunning }
        AppModel.workout.start(saved)
        return .result()
    }
}

struct PauseWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Pause Workout"
    static let description = IntentDescription("Pauses the running workout.")

    @MainActor
    func perform() async throws -> some IntentResult {
        guard AppModel.workout.engine?.phase == .running else { throw ShortcutError.nothingToPause }
        AppModel.workout.pause()
        return .result()
    }
}

struct ResumeWorkoutIntent: AppIntent {
    static let title: LocalizedStringResource = "Resume Workout"
    static let description = IntentDescription("Resumes the paused workout.")

    @MainActor
    func perform() async throws -> some IntentResult {
        guard AppModel.workout.engine?.phase == .paused else { throw ShortcutError.nothingToResume }
        AppModel.workout.resume()
        return .result()
    }
}

/// Spoken or shown by Siri and Shortcuts.
enum ShortcutError: Error, CustomLocalizedStringResourceConvertible {
    case timerNotFound, workoutRunning, nothingToPause, nothingToResume

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .timerNotFound: "This timer no longer exists."
        case .workoutRunning: "A workout is already running."
        case .nothingToPause: "No workout is running."
        case .nothingToResume: "No workout is paused."
        }
    }
}

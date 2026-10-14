import SetLoopCore
import SwiftData
import SwiftUI

@main
struct SetLoopApp: App {
    @State private var workout = WorkoutController()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(workout)
        }
        .modelContainer(for: [SavedTimer.self, WorkoutRecord.self]) { result in
            if case .success(let container) = result {
                PresetSeeder.seedIfNeeded(container.mainContext)
            }
        }
    }
}

/// Creates the example timers once, on first launch (SPEC D9).
enum PresetSeeder {
    private static let key = "didSeedPresets"

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let names = Presets.Names(
            prepare: String(localized: "Prepare"),
            work: String(localized: "Work"),
            rest: String(localized: "Rest"),
            restBetweenSets: String(localized: "Rest between sets"),
            tabata: String(localized: "Tabata 20/10"),
            simpleInterval: String(localized: "Simple interval"),
            twoBlocks: String(localized: "Your example")
        )
        for (index, preset) in Presets.all(names).enumerated() {
            context.insert(SavedTimer(name: preset.name, definition: preset.definition, sortIndex: index))
        }
        UserDefaults.standard.set(true, forKey: key)
    }
}

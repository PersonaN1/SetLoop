import SetLoopCore
import SwiftData
import SwiftUI

@main
struct SetLoopApp: App {
    @State private var settings: AppSettings
    @State private var workout: WorkoutController

    init() {
        let settings = AppSettings()
        _settings = State(initialValue: settings)
        _workout = State(initialValue: WorkoutController(settings: settings))
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(settings)
                .environment(workout)
                .preferredColorScheme(settings.theme.colorScheme)
        }
        .modelContainer(for: [SavedTimer.self, WorkoutRecord.self]) { result in
            if case .success(let container) = result {
                PresetSeeder.seedIfNeeded(container.mainContext)
                DefaultNames.relocalize(container.mainContext)
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
        try? context.save()
        UserDefaults.standard.set(true, forKey: key)
    }
}

/// Example timers and default step names follow the interface language: after switching to Russian,
/// "Work" reads "Работа". A name the user typed is left alone unless it equals a default name.
enum DefaultNames {
    private static let keys = [
        "Prepare", "Work", "Rest", "Rest between sets", "Cooldown",
        "Tabata 20/10", "Simple interval", "Your example",
    ]

    @MainActor
    static func relocalize(_ context: ModelContext) {
        let names = translations()
        guard let timers = try? context.fetch(FetchDescriptor<SavedTimer>()) else { return }
        for timer in timers {
            if let name = names[timer.name], name != timer.name { timer.name = name }
            var definition = timer.definition
            if definition.renameSteps({ names[$0] }) { timer.definition = definition }
        }
        if context.hasChanges { try? context.save() }
    }

    /// The default name in every bundled language → the same name in the current language.
    private static func translations() -> [String: String] {
        let bundles = Bundle.main.localizations.compactMap { language in
            Bundle.main.path(forResource: language, ofType: "lproj").flatMap(Bundle.init(path:))
        }
        var result: [String: String] = [:]
        for key in keys {
            let current = Bundle.main.localizedString(forKey: key, value: key, table: nil)
            result[key] = current
            for bundle in bundles {
                result[bundle.localizedString(forKey: key, value: key, table: nil)] = current
            }
        }
        return result
    }
}

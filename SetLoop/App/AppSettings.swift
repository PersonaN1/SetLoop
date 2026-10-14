import Foundation
import Observation
import SetLoopCore
import SwiftUI

/// User preferences from the Settings tab (SPEC D22), kept in UserDefaults.
@MainActor
@Observable
final class AppSettings {
    enum Theme: String, CaseIterable {
        case system, light, dark

        var colorScheme: ColorScheme? {
            switch self {
            case .system: nil
            case .light: .light
            case .dark: .dark
            }
        }
    }

    // Workout
    var pauseOnInterruption: Bool { didSet { defaults.set(pauseOnInterruption, forKey: Key.pauseOnInterruption) } }
    var showOnLockScreen: Bool { didSet { defaults.set(showOnLockScreen, forKey: Key.showOnLockScreen) } }
    var keepScreenOn: Bool { didSet { defaults.set(keepScreenOn, forKey: Key.keepScreenOn) } }

    // Sound and haptics
    var vibration: Bool { didSet { defaults.set(vibration, forKey: Key.vibration) } }
    var voicePrompts: Bool { didSet { defaults.set(voicePrompts, forKey: Key.voicePrompts) } }
    var ignoreSilentMode: Bool { didSet { defaults.set(ignoreSilentMode, forKey: Key.ignoreSilentMode) } }
    /// `nil` is "Off".
    var soundSet: SoundSet? { didSet { defaults.set(soundSet?.rawValue ?? Self.off, forKey: Key.soundSet) } }

    // Appearance
    var theme: Theme { didSet { defaults.set(theme.rawValue, forKey: Key.theme) } }
    var stepColors: StepColors {
        didSet { defaults.set(try? JSONEncoder().encode(stepColors), forKey: Key.stepColors) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // Defaults from SPEC D5–D7.
        defaults.register(defaults: [
            Key.pauseOnInterruption: true,
            Key.showOnLockScreen: true,
            Key.keepScreenOn: true,
            Key.vibration: true,
            Key.voicePrompts: false,
            Key.ignoreSilentMode: true,
            Key.soundSet: SoundSet.classic.rawValue,
        ])
        pauseOnInterruption = defaults.bool(forKey: Key.pauseOnInterruption)
        showOnLockScreen = defaults.bool(forKey: Key.showOnLockScreen)
        keepScreenOn = defaults.bool(forKey: Key.keepScreenOn)
        vibration = defaults.bool(forKey: Key.vibration)
        voicePrompts = defaults.bool(forKey: Key.voicePrompts)
        ignoreSilentMode = defaults.bool(forKey: Key.ignoreSilentMode)
        soundSet = defaults.string(forKey: Key.soundSet).flatMap(SoundSet.init)
        theme = defaults.string(forKey: Key.theme).flatMap(Theme.init) ?? .system
        stepColors = defaults.data(forKey: Key.stepColors)
            .flatMap { try? JSONDecoder().decode(StepColors.self, from: $0) } ?? .default
    }

    private static let off = "off"

    private enum Key {
        static let pauseOnInterruption = "pauseOnInterruption"
        static let showOnLockScreen = "showOnLockScreen"
        static let keepScreenOn = "keepScreenOn"
        static let vibration = "vibration"
        static let voicePrompts = "voicePrompts"
        static let ignoreSilentMode = "ignoreSilentMode"
        static let soundSet = "soundSet"
        static let theme = "theme"
        static let stepColors = "stepColors"
    }
}

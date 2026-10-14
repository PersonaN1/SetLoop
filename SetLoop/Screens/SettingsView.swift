import SetLoopCore
import SwiftUI

/// Groups: Workout / Sound and haptics / Appearance / About (SPEC D22, DESIGN V8).
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(WorkoutController.self) private var workout

    var body: some View {
        @Bindable var settings = settings
        NavigationStack {
            Form {
                Section {
                    Toggle("Pause on Calls", isOn: $settings.pauseOnInterruption)
                    Toggle("Show on Lock Screen", isOn: $settings.showOnLockScreen)
                    Toggle("Keep Screen On", isOn: $settings.keepScreenOn)
                } header: {
                    Text("Workout")
                } footer: {
                    // SPEC D6: with the setting off the timer keeps running, but iOS silences it during a call.
                    if !settings.pauseOnInterruption {
                        Text("Signals don't play during a call.")
                    }
                }

                Section {
                    Picker("Sounds", selection: $settings.soundSet) {
                        Text("Off").tag(SoundSet?.none)
                        ForEach(SoundSet.allCases, id: \.self) { set in
                            Text(set.title).tag(SoundSet?.some(set))
                        }
                    }
                    .onChange(of: settings.soundSet) { _, set in
                        if let set { workout.previewSound(set) }
                    }
                    Toggle("Voice Prompts", isOn: $settings.voicePrompts)
                    Toggle("Vibration", isOn: $settings.vibration)
                    Toggle("Ignore Silent Mode", isOn: $settings.ignoreSilentMode)
                } header: {
                    Text("Sound and Haptics")
                } footer: {
                    // TECH T2: without audio iOS freezes the app on the lock screen.
                    if settings.soundSet == nil && !settings.voicePrompts {
                        Text("Without sounds or voice, steps on the Lock Screen change only when you open the app.")
                    } else if !settings.ignoreSilentMode {
                        Text("Signals follow the Silent switch and stop when the screen locks.")
                    }
                }

                Section("Appearance") {
                    Picker("Theme", selection: $settings.theme) {
                        ForEach(AppSettings.Theme.allCases, id: \.self) { theme in
                            Text(theme.title).tag(theme)
                        }
                    }
                    NavigationLink("Step Colors") { StepColorsView() }
                }

                Section("About") {
                    Link("Privacy Policy", destination: SupportLinks.privacy)
                    Link("Support", destination: SupportLinks.support)
                    LabeledContent("Version", value: Bundle.main.versionString)
                }
            }
            .navigationTitle("Settings")
        }
    }
}

/// Pages in the project's GitHub Pages site (SPEC D20).
enum SupportLinks {
    static let privacy = URL(string: "https://personan1.github.io/SetLoop/privacy/")!
    static let support = URL(string: "https://personan1.github.io/SetLoop/support/")!
}

extension SoundSet {
    var title: String {
        switch self {
        case .glass: String(localized: "Glass")
        case .marimba: String(localized: "Marimba")
        case .note: String(localized: "Note")
        }
    }
}

extension AppSettings.Theme {
    var title: String {
        switch self {
        case .system: String(localized: "System")
        case .light: String(localized: "Light")
        case .dark: String(localized: "Dark")
        }
    }
}

extension Bundle {
    var versionString: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(version) (\(build))"
    }
}

import SwiftUI

/// Groups: Workout / Sound and haptics / Appearance / About (SPEC D22, DESIGN V8).
struct SettingsView: View {
    @Environment(AppSettings.self) private var settings

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

                Section("Sound and Haptics") {
                    Toggle("Vibration", isOn: $settings.vibration)
                    Toggle("Voice Prompts", isOn: $settings.voicePrompts)
                    Toggle("Ignore Silent Mode", isOn: $settings.ignoreSilentMode)
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

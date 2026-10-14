import SwiftUI

struct SettingsView: View {
    var body: some View {
        NavigationStack {
            List {
                LabeledContent("Version", value: Bundle.main.versionString)
            }
            .navigationTitle("Settings")
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

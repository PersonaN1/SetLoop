import SwiftUI

/// Tabs: Timers · History · Settings (SPEC D21).
struct RootView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(\.scenePhase) private var scenePhase
    /// "Show Tips Again" rebuilds the tabs so every tip view picks up the new tip IDs.
    @AppStorage("tipsGeneration") private var tipsGeneration = 0

    var body: some View {
        @Bindable var workout = workout
        TabView {
            TimerListView()
                .tabItem { Label("Timers", systemImage: "timer") }
            HistoryView()
                .tabItem { Label("History", systemImage: "clock.arrow.circlepath") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
        .id(tipsGeneration)
        .fullScreenCover(isPresented: .constant(workout.isPresented)) {
            WorkoutView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { workout.appDidBecomeActive() }
        }
    }
}

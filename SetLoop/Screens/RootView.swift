import SwiftUI

/// Tabs: Timers · History · Settings (SPEC D21).
struct RootView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(\.scenePhase) private var scenePhase

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
        .fullScreenCover(isPresented: .constant(workout.isPresented)) {
            WorkoutView()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { workout.appDidBecomeActive() }
        }
    }
}

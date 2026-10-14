import SetLoopCore
import SwiftData
import SwiftUI

struct TimerListView: View {
    @Environment(WorkoutController.self) private var workout
    @Query(sort: \SavedTimer.sortIndex) private var timers: [SavedTimer]

    var body: some View {
        NavigationStack {
            List(timers) { timer in
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(timer.name).font(.headline)
                        Text(WorkoutFormat.time(TimeInterval(timer.totalDuration)))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Spacer()
                    Button {
                        workout.start(timer)
                    } label: {
                        Image(systemName: "play.fill")
                    }
                    .accessibilityLabel("Start \(timer.name)")
                }
            }
            .navigationTitle("Timers")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Text("\(timers.count)/\(Limits.maxTimers)")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
        }
    }
}

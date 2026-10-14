import SetLoopCore
import SwiftData
import SwiftUI

struct TimerListView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedTimer.sortIndex) private var timers: [SavedTimer]

    @State private var editMode = EditMode.inactive
    @State private var selection = Set<PersistentIdentifier>()
    @State private var pendingDelete: Set<PersistentIdentifier>?

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                // Rows are tagged by persistent ID to match the selection (the model's own `id` is a UUID).
                ForEach(timers, id: \.persistentModelID) { timer in
                    row(timer)
                        .swipeActions {
                            // No destructive role: it would remove the row before the confirmation.
                            Button("Delete", systemImage: "trash") {
                                pendingDelete = [timer.persistentModelID]
                            }
                            .tint(.red)
                        }
                }
            }
            .overlay {
                if timers.isEmpty {
                    ContentUnavailableView("No timers", systemImage: "timer")
                }
            }
            .navigationTitle("Timers")
            .selectionToolbar(
                editMode: $editMode,
                selection: $selection,
                pendingDelete: $pendingDelete,
                allIDs: timers.map(\.persistentModelID),
                confirmationTitle: { Text("Delete \($0) timers?") },
                delete: { context.delete(ids: $0) }
            )
        }
    }

    private func row(_ timer: SavedTimer) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(timer.name).font(.headline)
                Text(WorkoutFormat.time(TimeInterval(timer.totalDuration)))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            if !editMode.isEditing {
                Button {
                    workout.start(timer)
                } label: {
                    Image(systemName: "play.fill")
                }
                // Only the button starts; the row will open the preview (SPEC D9).
                .buttonStyle(.borderless)
                .accessibilityLabel("Start \(timer.name)")
            }
        }
    }
}

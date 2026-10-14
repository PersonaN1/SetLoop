import SetLoopCore
import SwiftData
import SwiftUI

/// Timer cards with preview strips (SPEC D9, DESIGN V4).
struct TimerListView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(\.modelContext) private var context
    @Query(sort: \SavedTimer.sortIndex) private var timers: [SavedTimer]

    @State private var editMode = EditMode.inactive
    @State private var selection = Set<PersistentIdentifier>()
    @State private var pendingDelete: Set<PersistentIdentifier>?
    @State private var editor: EditorTarget?
    @State private var limitReached = false

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                // Rows are tagged by persistent ID to match the selection (the model's own `id` is a UUID).
                ForEach(timers, id: \.persistentModelID) { timer in
                    NavigationLink(value: timer) { card(timer) }
                        .swipeActions {
                            // No destructive role: it would remove the row before the confirmation.
                            Button("Delete", systemImage: "trash") {
                                pendingDelete = [timer.persistentModelID]
                            }
                            .tint(.red)
                            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(timer) }
                                .tint(.gray)
                            Button("Edit", systemImage: "pencil") { editor = .edit(timer) }
                                .tint(.orange)
                        }
                        .contextMenu {
                            Button("Edit", systemImage: "pencil") { editor = .edit(timer) }
                            Button("Duplicate", systemImage: "plus.square.on.square") { duplicate(timer) }
                            Button("Delete", systemImage: "trash", role: .destructive) {
                                pendingDelete = [timer.persistentModelID]
                            }
                        }
                }
                .onMove(perform: move)
            }
            .overlay {
                if timers.isEmpty {
                    ContentUnavailableView {
                        Label("No timers", systemImage: "timer")
                    } actions: {
                        Button("New Timer") { add() }
                    }
                }
            }
            .navigationTitle("Timers")
            .navigationDestination(for: SavedTimer.self) { TimerPreviewView(timer: $0) }
            .toolbar {
                if !editMode.isEditing {
                    // iOS 26+ merges neighbouring items into one glass capsule; keep "+" on its own.
                    if #available(iOS 26, *) {
                        ToolbarSpacer(.fixed, placement: .topBarTrailing)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("New Timer", systemImage: "plus") { add() }
                    }
                }
            }
            .selectionToolbar(
                editMode: $editMode,
                selection: $selection,
                pendingDelete: $pendingDelete,
                allIDs: timers.map(\.persistentModelID),
                confirmationTitle: { Text("Delete \($0) timers?") },
                delete: { context.delete(ids: $0) }
            )
            .sheet(item: $editor) { target in
                TimerEditorView(timer: target.timer)
            }
            .timerLimitAlert(isPresented: $limitReached)
        }
    }

    private func card(_ timer: SavedTimer) -> some View {
        let definition = timer.definition
        return VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(timer.name).font(.headline)
                    Text("\(WorkoutFormat.duration(timer.totalDuration)) · \(definition.structureText())")
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
                            .foregroundStyle(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.accentColor, in: Circle())
                    }
                    // Only the button starts; the row opens the preview (SPEC D9).
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Start \(timer.name)")
                }
            }
            TimerStrip(definition: definition, colors: workout.colors)
        }
        .padding(.vertical, 4)
    }

    private func add() {
        if timers.count >= Limits.maxTimers { limitReached = true } else { editor = .new }
    }

    private func duplicate(_ timer: SavedTimer) {
        if !context.duplicate(timer) { limitReached = true }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = timers
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, timer) in ordered.enumerated() where timer.sortIndex != index {
            timer.sortIndex = index
        }
        try? context.save()
    }
}

private enum EditorTarget: Identifiable {
    case new
    case edit(SavedTimer)

    var id: String {
        switch self {
        case .new: "new"
        case .edit(let timer): "\(timer.persistentModelID.hashValue)"
        }
    }

    var timer: SavedTimer? {
        if case .edit(let timer) = self { timer } else { nil }
    }
}

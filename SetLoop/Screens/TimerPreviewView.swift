import SetLoopCore
import SwiftData
import SwiftUI

/// Read-only preview with a pinned Start button (DESIGN V9).
struct TimerPreviewView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    let timer: SavedTimer

    @State private var isEditing = false
    @State private var confirmingDelete = false
    @State private var limitReached = false

    var body: some View {
        // A deleted model must not be read; the screen is about to close anyway.
        if timer.isDeleted || timer.modelContext == nil {
            Color.clear
        } else {
            content(timer.definition)
        }
    }

    private func content(_ definition: TimerDefinition) -> some View {
        let plan = definition.plan
        return List {
            Section {
                VStack(alignment: .leading, spacing: 14) {
                    Text(definition.structureText(includingSteps: true))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(WorkoutFormat.duration(plan.totalDuration))
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .monospacedDigit()
                        .accessibilityLabel(WorkoutFormat.longDuration(plan.totalDuration))
                    TimerStrip(definition: definition, colors: workout.colors, height: 12)
                    HStack {
                        Metric(title: "Work", value: WorkoutFormat.duration(plan.duration(of: .work)))
                        Metric(title: "Rest", value: WorkoutFormat.duration(plan.duration(of: .rest)))
                        Metric(title: "Other", value: WorkoutFormat.duration(plan.duration(of: .other)))
                    }
                }
                .padding(.vertical, 6)
            }
            Section("Structure") {
                structure(definition)
            }
        }
        .navigationTitle(timer.name)
        .safeAreaInset(edge: .bottom) {
            Button { workout.start(timer) } label: {
                Label("Start", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .disabled(workout.isPresented)
            .padding()
            .background(.bar)
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Edit", systemImage: "pencil") { isEditing = true }
                Menu("More", systemImage: "ellipsis.circle") {
                    Button("Edit", systemImage: "pencil") { isEditing = true }
                    Button("Duplicate", systemImage: "plus.square.on.square") {
                        if !context.duplicate(timer) { limitReached = true }
                    }
                    Button("Delete", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                }
            }
        }
        .sheet(isPresented: $isEditing) { TimerEditorView(timer: timer) }
        .confirmationDialog("Delete this timer?", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                context.delete(timer)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Workouts in History stay.")
        }
        .timerLimitAlert(isPresented: $limitReached)
    }

    @ViewBuilder
    private func structure(_ definition: TimerDefinition) -> some View {
        if let prepare = definition.prepare { row(prepare) }
        if definition.sets > 1 {
            HStack {
                Text("Sets").fontWeight(.semibold)
                Spacer()
                Text(definition.restBetweenSets.map {
                    String(localized: "× \(definition.sets) · rest \(WorkoutFormat.duration($0.duration))")
                } ?? "× \(definition.sets)")
                .foregroundStyle(.secondary)
            }
        }
        ForEach(Array(definition.blocks.enumerated()), id: \.element.id) { index, block in
            HStack {
                Text("Block \(index + 1)").fontWeight(.semibold)
                Spacer()
                if block.repeats > 1 {
                    Text("× \(block.repeats)").foregroundStyle(.secondary)
                }
            }
            ForEach(block.steps) { row($0).padding(.leading, 24) }
        }
        if let cooldown = definition.cooldown { row(cooldown) }
    }

    private func row(_ step: Step) -> some View {
        HStack(spacing: 12) {
            TypeDot(color: workout.colors[step.type].color)
            Text(step.name)
            Spacer()
            Text(WorkoutFormat.duration(step.duration)).foregroundStyle(.secondary).monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }
}

extension ModelContext {
    /// Inserts a copy right after the original; false at the timer limit (SPEC D9).
    @discardableResult
    func duplicate(_ timer: SavedTimer) -> Bool {
        let all = (try? fetch(FetchDescriptor<SavedTimer>())) ?? []
        guard all.count < Limits.maxTimers else { return false }
        for other in all where other.sortIndex > timer.sortIndex { other.sortIndex += 1 }
        insert(SavedTimer(name: TimerNaming.unique(timer.name, among: all.map(\.name)),
                          definition: timer.definition,
                          sortIndex: timer.sortIndex + 1))
        try? save()
        return true
    }
}

extension View {
    /// Shown only when adding or duplicating is refused; the list has no counter (SPEC D9).
    func timerLimitAlert(isPresented: Binding<Bool>) -> some View {
        alert("Timer limit reached", isPresented: isPresented) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("You can keep up to \(Limits.maxTimers) timers. Delete old ones to add a new one.")
        }
    }
}

import SetLoopCore
import SwiftData
import SwiftUI

/// One saved workout: steps with outcomes, editable name and note, delete, repeat (SPEC D10).
struct RecordDetailView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Bindable var record: WorkoutRecord
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    HStack {
                        Text(WorkoutFormat.duration(record.duration))
                            .font(.system(.title, design: .rounded, weight: .bold))
                            .monospacedDigit()
                        Spacer()
                        StatusBadge(status: record.status)
                    }
                    HStack {
                        Metric(title: "Work", value: WorkoutFormat.duration(record.workTime))
                        Metric(title: "Rest", value: WorkoutFormat.duration(record.restTime))
                        Metric(title: "Steps", value: "\(record.completedSteps)/\(record.totalSteps)")
                    }
                    StepStrip(steps: record.steps, colors: workout.colors)
                }
                .padding(.vertical, 4)
            } footer: {
                Text(record.startedAt, format: .dateTime.weekday(.wide).day().month().year().hour().minute())
            }

            Section {
                TextField("Name", text: $record.name)
                    .submitLabel(.done)
                TextField("Note", text: $record.note, axis: .vertical)
            }

            Section("Steps") {
                ForEach(Array(record.steps.enumerated()), id: \.offset) { _, step in
                    StepRow(record: step, color: workout.colors[step.step.type].color)
                }
            }

            Section {
                Button("Repeat", systemImage: "arrow.clockwise") { repeatWorkout() }
                    .disabled(record.definition == nil || workout.isPresented)
                Button("Delete Workout", systemImage: "trash", role: .destructive) { confirmingDelete = true }
                    // Attached to the button so the iOS 26+ popover points at it.
                    .confirmationDialog("Delete this workout?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                        Button("Delete", role: .destructive) {
                            context.delete(record)
                            try? context.save()
                            dismiss()
                        }
                    }
            }
        }
        .scrollDismissesKeyboard(.immediately)
        .navigationTitle(record.name)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func repeatWorkout() {
        guard let definition = record.definition else { return }
        workout.start(name: record.name, definition: definition)
    }
}

private struct StepRow: View {
    let record: StepRecord
    let color: Color

    var body: some View {
        HStack {
            Circle().fill(color).frame(width: 10, height: 10)
            Text(record.step.name)
            Spacer()
            // Time actually spent; a step left early also shows its planned length.
            Text(record.outcome == .completed
                 ? WorkoutFormat.duration(record.elapsed)
                 : "\(WorkoutFormat.duration(record.elapsed)) / \(WorkoutFormat.duration(record.step.duration))")
                .monospacedDigit()
                .foregroundStyle(.secondary)
            outcome
        }
        .opacity(record.outcome == .skipped ? 0.5 : 1)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var outcome: some View {
        switch record.outcome {
        case .completed:
            Image(systemName: "checkmark").foregroundStyle(.green).accessibilityLabel("Completed")
        case .skipped:
            Image(systemName: "forward.end").foregroundStyle(.secondary).accessibilityLabel("Skipped")
        case .interrupted:
            Image(systemName: "stop.fill").foregroundStyle(.orange).accessibilityLabel("Interrupted")
        }
    }
}

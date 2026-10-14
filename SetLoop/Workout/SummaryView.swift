import SetLoopCore
import SwiftData
import SwiftUI

/// Shown after the last step or an early finish: save to history or discard (SPEC D10, DESIGN V5).
struct SummaryView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(\.modelContext) private var context
    let summary: WorkoutSummary

    @State private var name = ""
    @State private var note = ""
    @State private var savedCount = 0

    private var historyFull: Bool { savedCount >= Limits.maxHistoryRecords }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    metrics
                    StepStrip(steps: summary.steps, colors: workout.colors)
                    fields
                    if historyFull { fullHint }
                }
                .padding()
                .frame(maxWidth: 600)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.immediately)
            .safeAreaInset(edge: .bottom) { buttons }
            .navigationTitle("Summary")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            name = workout.timerName
            savedCount = (try? context.fetchCount(FetchDescriptor<WorkoutRecord>())) ?? 0
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Image(systemName: summary.status == .complete ? "checkmark.circle.fill" : "flag.checkered.circle.fill")
                .font(.system(size: 56))
                .foregroundStyle(summary.status == .complete ? Color.green : Color.orange)
            Text(WorkoutFormat.duration(summary.duration))
                .font(.system(.largeTitle, design: .rounded, weight: .bold))
                .monospacedDigit()
                .accessibilityLabel(WorkoutFormat.longDuration(summary.duration))
            StatusBadge(status: summary.status)
        }
        .padding(.top)
    }

    private var metrics: some View {
        HStack {
            Metric(title: "Work", value: WorkoutFormat.duration(summary.time(of: .work)))
            Metric(title: "Rest", value: WorkoutFormat.duration(summary.time(of: .rest)))
            Metric(title: "Steps", value: "\(summary.completedSteps)/\(summary.totalSteps)")
        }
    }

    private var fields: some View {
        VStack(spacing: 12) {
            TextField("Name", text: $name)
                .submitLabel(.done)
                .nameLimit($name)
            TextField("Note (optional)", text: $note, axis: .vertical)
                .lineLimit(2...5)
        }
        .textFieldStyle(.roundedBorder)
    }

    private var fullHint: some View {
        Label("History is full (\(Limits.maxHistoryRecords)). Saving removes the oldest workout.",
              systemImage: "info.circle")
            .font(.footnote)
            .foregroundStyle(.secondary)
    }

    private var buttons: some View {
        VStack(spacing: 8) {
            Button {
                save()
            } label: {
                Text("Save").font(.headline).frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            Button("Don't Save", role: .destructive) { workout.close() }
                .frame(minHeight: 44)
        }
        .padding()
        .background(.bar)
    }

    private func save() {
        if historyFull { removeOldest(savedCount - Limits.maxHistoryRecords + 1) }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        context.insert(WorkoutRecord(
            name: trimmed.isEmpty ? workout.timerName : trimmed,
            note: note.trimmingCharacters(in: .whitespacesAndNewlines),
            startedAt: workout.startedAt,
            summary: summary,
            definition: workout.definition
        ))
        try? context.save()
        workout.close()
    }

    private func removeOldest(_ count: Int) {
        var oldest = FetchDescriptor<WorkoutRecord>(sortBy: [SortDescriptor(\.startedAt)])
        oldest.fetchLimit = count
        for record in (try? context.fetch(oldest)) ?? [] { context.delete(record) }
    }
}

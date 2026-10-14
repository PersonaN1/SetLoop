import SetLoopCore
import SwiftData
import SwiftUI

/// Saved workouts by day with this week's totals (SPEC D10, DESIGN V6).
struct HistoryView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(\.modelContext) private var context
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var records: [WorkoutRecord]

    @State private var editMode = EditMode.inactive
    @State private var selection = Set<PersistentIdentifier>()

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                if !records.isEmpty {
                    Section { weekSummary }
                }
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.records, id: \.persistentModelID) { record in
                            NavigationLink(value: record) { HistoryRow(record: record, colors: workout.colors) }
                                .swipeActions {
                                    Button("Delete", systemImage: "trash", role: .destructive) {
                                        context.delete(record)
                                        context.saveOrReport()
                                    }
                                }
                        }
                    } header: {
                        Text(group.day, format: .dateTime.weekday(.wide).day().month(.wide))
                    }
                }
            }
            .overlay {
                if records.isEmpty {
                    ContentUnavailableView(
                        "No workouts yet",
                        systemImage: "clock.arrow.circlepath",
                        description: Text("Finished workouts you save appear here.")
                    )
                }
            }
            .navigationTitle("History")
            .navigationDestination(for: WorkoutRecord.self) { RecordDetailView(record: $0) }
            .selectionToolbar(
                editMode: $editMode,
                selection: $selection,
                allIDs: records.map(\.persistentModelID),
                confirmationTitle: { Text("Delete \($0) workouts?") },
                delete: { context.delete(ids: $0) }
            )
        }
    }

    private var days: [(day: Date, records: [WorkoutRecord])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: records) { calendar.startOfDay(for: $0.startedAt) }
        return grouped.keys.sorted(by: >).map { ($0, grouped[$0] ?? []) }
    }

    private var weekSummary: some View {
        let week = Calendar.current.dateInterval(of: .weekOfYear, for: .now)
        let thisWeek = records.filter { week?.contains($0.startedAt) ?? false }
        return VStack(alignment: .leading, spacing: 8) {
            Text("This week").font(.footnote).foregroundStyle(.secondary)
            HStack {
                Metric(title: "Workouts", value: "\(thisWeek.count)")
                Metric(title: "Time", value: WorkoutFormat.longDuration(thisWeek.reduce(0) { $0 + $1.duration }))
            }
        }
        .padding(.vertical, 4)
    }
}

private struct HistoryRow: View {
    let record: WorkoutRecord
    let colors: StepColors

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(record.name).font(.body.weight(.semibold))
                Spacer()
                Text(WorkoutFormat.duration(record.duration)).monospacedDigit()
            }
            HStack {
                Text(record.startedAt, format: .dateTime.hour().minute())
                if record.status == .partial {
                    Text("· Partial")
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            StepStrip(steps: record.steps, colors: colors, height: 6)
        }
        .padding(.vertical, 4)
    }
}

import SwiftData
import SwiftUI

struct HistoryView: View {
    @Query(sort: \WorkoutRecord.startedAt, order: .reverse) private var records: [WorkoutRecord]

    var body: some View {
        NavigationStack {
            List(records) { record in
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.name).font(.headline)
                    Text(record.startedAt, style: .date).font(.subheadline).foregroundStyle(.secondary)
                }
            }
            .overlay {
                if records.isEmpty {
                    ContentUnavailableView("No workouts yet", systemImage: "clock.arrow.circlepath")
                }
            }
            .navigationTitle("History")
        }
    }
}

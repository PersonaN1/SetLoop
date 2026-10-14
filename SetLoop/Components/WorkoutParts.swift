import SetLoopCore
import SwiftUI

/// Strip of passed steps: completed ones bright, skipped ones at 25% (DESIGN V5, V6).
struct StepStrip: View {
    let steps: [StepRecord]
    var colors = StepColors.default
    var height: CGFloat = 8

    var body: some View {
        Canvas { context, size in
            let segments = StripLayout.segments(for: steps.map(\.step.duration), in: size.width)
            for (step, segment) in zip(steps, segments) {
                let rect = CGRect(x: segment.x, y: 0, width: segment.width, height: size.height)
                let color = colors[step.step.type].color.opacity(step.outcome == .skipped ? 0.25 : 1)
                context.fill(Path(roundedRect: rect, cornerRadius: min(2, segment.width / 2)), with: .color(color))
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}

struct StatusBadge: View {
    let status: WorkoutStatus

    var body: some View {
        Text(status == .complete ? "Completed" : "Partial")
            .font(.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .foregroundStyle(status == .complete ? Color.green : Color.orange)
            .background((status == .complete ? Color.green : Color.orange).opacity(0.15), in: Capsule())
    }
}

/// A value with a caption under it, used in summary and history headers.
struct Metric: View {
    let title: LocalizedStringKey
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value).font(.title3.weight(.semibold)).monospacedDigit()
            Text(title).font(.footnote).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

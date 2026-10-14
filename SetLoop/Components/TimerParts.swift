import SetLoopCore
import SwiftUI

extension StepType {
    /// Name in the type list of the step sheet (DESIGN V2).
    var title: String {
        switch self {
        case .prepare: String(localized: "Prepare")
        case .workA: String(localized: "Work A")
        case .workB: String(localized: "Work B")
        case .workC: String(localized: "Work C")
        case .rest: String(localized: "Rest")
        case .cooldown: String(localized: "Cooldown")
        }
    }

    /// Default name for a new step of this type.
    var defaultStepName: String {
        switch self {
        case .prepare: String(localized: "Prepare")
        case .workA, .workB, .workC: String(localized: "Work")
        case .rest: String(localized: "Rest")
        case .cooldown: String(localized: "Cooldown")
        }
    }
}

extension TimerDefinition {
    /// "1 block · 3 sets", plus "· 33 steps" when asked (DESIGN V9).
    func structureText(includingSteps: Bool = false) -> String {
        var parts = [String(localized: "\(blocks.count) blocks")]
        if sets > 1 { parts.append(String(localized: "\(sets) sets")) }
        if includingSteps { parts.append(String(localized: "\(stepCount) steps")) }
        return parts.joined(separator: " · ")
    }
}

/// Small colored square for a step type.
struct TypeDot: View {
    let color: Color

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 12, height: 12)
            .accessibilityHidden(true)
    }
}

/// A step name with its color mark and time. At accessibility text sizes the time goes under the name,
/// so the name is not broken mid-word.
struct StepLine<Mark: View, Detail: View>: View {
    let name: String
    @ViewBuilder let mark: Mark
    @ViewBuilder let detail: Detail
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 12) {
            mark
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                    HStack { detail }
                }
                Spacer(minLength: 0)
            } else {
                Text(name)
                Spacer()
                detail
            }
        }
    }
}

/// A step length in the list, read out in words by VoiceOver.
struct StepDuration: View {
    let seconds: Int

    var body: some View {
        Text(WorkoutFormat.duration(seconds))
            .foregroundStyle(.secondary)
            .monospacedDigit()
            .accessibilityLabel(WorkoutFormat.spokenDuration(seconds))
    }
}

/// Timer structure strip with the detail level picked by DESIGN V4.
struct TimerStrip: View {
    let definition: TimerDefinition
    var colors = StepColors.default
    var height: CGFloat = 10

    var body: some View {
        let strip = PreviewStrip(definition)
        let labeled = strip.groups.contains { $0.repeats > 1 }
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(Array(strip.groups.enumerated()), id: \.offset) { _, group in
                VStack(alignment: .leading, spacing: 2) {
                    if labeled {
                        Text(group.repeats > 1 ? "×\(group.repeats)" : " ")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    segments(group.segments)
                }
                // Several groups only appear on levels 3–4, where blocks share the width equally.
                .frame(maxWidth: .infinity)
            }
        }
        .accessibilityHidden(true)
    }

    private func segments(_ segments: [PreviewStrip.Segment]) -> some View {
        Canvas { context, size in
            let layout = StripLayout.segments(for: segments.map(\.duration), in: size.width)
            for (segment, frame) in zip(segments, layout) {
                let rect = CGRect(x: frame.x, y: 0, width: frame.width, height: size.height)
                context.fill(Path(roundedRect: rect, cornerRadius: min(2, frame.width / 2)),
                             with: .color(colors[segment.type].color))
            }
        }
        .frame(height: height)
        .clipShape(Capsule())
    }
}

extension View {
    /// Cuts a name typed or pasted into a text field to `Limits.maxNameLength`.
    func nameLimit(_ text: Binding<String>) -> some View {
        onChange(of: text.wrappedValue) { _, newValue in
            let capped = newValue.cappedName
            if capped != newValue { text.wrappedValue = capped }
        }
    }
}

import SetLoopCore
import SwiftUI

/// Full-screen workout, filled with the step color (SPEC D4, DESIGN V1).
struct WorkoutView: View {
    @Environment(WorkoutController.self) private var workout
    @Environment(\.verticalSizeClass) private var verticalSizeClass

    var body: some View {
        if let summary = workout.summary {
            SummaryView(summary: summary)
        } else {
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                if let engine = workout.engine {
                    content(engine)
                }
            }
        }
    }

    @ViewBuilder
    private func content(_ engine: WorkoutEngine) -> some View {
        let now = workout.now
        let step = engine.currentStep
        ZStack {
            (step.map { workout.colors[$0.type].color } ?? Color.black)
                .ignoresSafeArea()
            Group {
                if verticalSizeClass == .compact {
                    landscape(engine, step: step, now: now)
                } else {
                    portrait(engine, step: step, now: now)
                }
            }
            .foregroundStyle(.white)
            .tint(.white)
            .padding()
        }
    }

    private func portrait(_ engine: WorkoutEngine, step: PlannedStep?, now: TimeInterval) -> some View {
        VStack(spacing: 0) {
            // Equal fillers keep the timer centered; Finish sits midway between the controls and the bottom.
            Color.clear.frame(maxHeight: .infinity)
            if let step {
                VStack(spacing: 16) {
                    info(engine, step: step, now: now, digits: 120)
                    controls(engine)
                }
                // The fillers only get what is left, so the digits never shrink for them.
                .layoutPriority(1)
            }
            Color.clear.frame(maxHeight: .infinity)
                .overlay { finishButton }
        }
    }

    /// The phone is too low for one column: the timer on the left, the buttons on the right.
    private func landscape(_ engine: WorkoutEngine, step: PlannedStep?, now: TimeInterval) -> some View {
        HStack(spacing: 24) {
            if let step {
                VStack(spacing: 8) {
                    info(engine, step: step, now: now, digits: 96)
                }
                .frame(maxWidth: .infinity)
            }
            VStack(spacing: 24) {
                controls(engine)
                finishButton
            }
            .frame(maxWidth: .infinity)
        }
    }

    @ViewBuilder
    private func info(_ engine: WorkoutEngine, step: PlannedStep, now: TimeInterval, digits: CGFloat) -> some View {
        Text(step.step.name)
            .font(.largeTitle.weight(.bold))
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .minimumScaleFactor(0.6)
            .padding(.bottom, verticalSizeClass == .compact ? 0 : 16)
        Text(WorkoutFormat.time(engine.stepRemaining(at: now)))
            .font(.system(size: digits, weight: .bold, design: .rounded))
            .monospacedDigit()
            .minimumScaleFactor(0.5)
            .accessibilityLabel(WorkoutFormat.spokenDuration(Int(engine.stepRemaining(at: now).rounded(.up))))
        // Both lines keep their height when empty (a space), so the controls below never jump.
        Text(nonEmpty(WorkoutFormat.position(step.position))).font(.headline)
        Text(nonEmpty(engine.nextStep.map { WorkoutFormat.next($0) })).font(.subheadline)
    }

    // The row never changes layout, so a button never moves under the finger.
    private func controls(_ engine: WorkoutEngine) -> some View {
        HStack(spacing: 40) {
            Button { workout.back() } label: { controlIcon("backward.end.fill") }
                .accessibilityLabel("Back")
            Button { workout.togglePause() } label: {
                controlIcon(engine.phase == .paused ? "play.fill" : "pause.fill", size: 88)
            }
            .accessibilityLabel(engine.phase == .paused ? "Resume" : "Pause")
            Button { workout.skip() } label: { controlIcon("forward.end.fill") }
                .accessibilityLabel("Skip")
        }
    }

    /// No confirmation: the summary that follows still lets the user discard or save (SPEC D3).
    private var finishButton: some View {
        Button { workout.finish() } label: {
            Text("Finish")
                .font(.title3.weight(.semibold))
                .padding(.horizontal, 36)
                .frame(minHeight: 56)
                .background(.white.opacity(0.18), in: Capsule())
                .contentShape(Capsule())
        }
    }

    private func nonEmpty(_ text: String?) -> String {
        guard let text, !text.isEmpty else { return " " }
        return text
    }

    private func controlIcon(_ name: String, size: CGFloat = 64) -> some View {
        Image(systemName: name)
            .font(.system(size: size * 0.4))
            .frame(width: size, height: size)
            .background(.white.opacity(0.18), in: Circle())
            .contentShape(Circle())
    }
}

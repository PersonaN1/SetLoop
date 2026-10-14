import SetLoopCore
import SwiftUI

/// Full-screen workout, filled with the step color (SPEC D4, DESIGN V1).
struct WorkoutView: View {
    @Environment(WorkoutController.self) private var workout

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
            VStack(spacing: 0) {
                // Equal fillers keep the timer centered; Finish sits midway between the controls and the bottom.
                Color.clear.frame(maxHeight: .infinity)
                if let step {
                    VStack(spacing: 16) {
                        Text(step.step.name).font(.title.weight(.semibold))
                        Text(WorkoutFormat.time(engine.stepRemaining(at: now)))
                            .font(.system(size: 120, weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .minimumScaleFactor(0.5)
                        // Both lines keep their height when empty (a space), so the controls below never jump.
                        Text(nonEmpty(WorkoutFormat.position(step.position))).font(.headline)
                        Text(nonEmpty(engine.nextStep.map { WorkoutFormat.next($0) })).font(.subheadline)
                        controls(engine)
                    }
                    // The fillers only get what is left, so the digits never shrink for them.
                    .layoutPriority(1)
                }
                Color.clear.frame(maxHeight: .infinity)
                    .overlay { finishButton }
            }
            .foregroundStyle(.white)
            .tint(.white)
            .padding()
        }
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

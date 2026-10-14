import SetLoopCore
import SwiftUI

/// Full-screen workout, filled with the step color (SPEC D4, DESIGN V1).
struct WorkoutView: View {
    @Environment(WorkoutController.self) private var workout
    @State private var confirmingFinish = false

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
            VStack(spacing: 16) {
                if let step {
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
            }
            .foregroundStyle(.white)
            .padding()
        }
    }

    private func controls(_ engine: WorkoutEngine) -> some View {
        VStack(spacing: 20) {
            // The row never changes layout, so a button never moves under the finger.
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
            Button("Finish") { confirmingFinish = true }
                .font(.headline)
                .frame(minHeight: 44)
                .opacity(engine.phase == .paused ? 1 : 0)
                .disabled(engine.phase != .paused)
        }
        .tint(.white)
        // Finishing early needs confirmation and leads to the summary (SPEC D3).
        .confirmationDialog("Finish the workout?", isPresented: $confirmingFinish, titleVisibility: .visible) {
            Button("Finish", role: .destructive) { workout.finish() }
        } message: {
            Text("Remaining steps will not be recorded.")
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

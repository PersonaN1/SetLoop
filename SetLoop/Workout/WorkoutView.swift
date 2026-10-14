import SetLoopCore
import SwiftUI

/// Full-screen workout, filled with the step color (SPEC D4, DESIGN V1).
struct WorkoutView: View {
    @Environment(WorkoutController.self) private var workout

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            if let engine = workout.engine {
                content(engine)
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
                if case .finished(let status) = engine.phase {
                    Text(status == .complete ? "Completed" : "Finished early").font(.largeTitle.bold())
                    Button("Done") { workout.close() }
                        .buttonStyle(.borderedProminent)
                } else if let step {
                    Text(step.step.name).font(.title.weight(.semibold))
                    Text(WorkoutFormat.time(engine.stepRemaining(at: now)))
                        .font(.system(size: 120, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.5)
                    Text(WorkoutFormat.position(step.position)).font(.headline)
                    if let next = engine.nextStep {
                        Text(WorkoutFormat.next(next)).font(.subheadline)
                    }
                    controls(engine)
                }
            }
            .foregroundStyle(.white)
            .padding()
        }
    }

    private func controls(_ engine: WorkoutEngine) -> some View {
        HStack(spacing: 32) {
            Button { workout.back() } label: { Image(systemName: "backward.end.fill") }
                .accessibilityLabel("Back")
            Button { workout.togglePause() } label: {
                Image(systemName: engine.phase == .paused ? "play.fill" : "pause.fill").font(.largeTitle)
            }
            .accessibilityLabel(engine.phase == .paused ? "Resume" : "Pause")
            Button { workout.skip() } label: { Image(systemName: "forward.end.fill") }
                .accessibilityLabel("Skip")
            if engine.phase == .paused {
                // TODO: confirmation dialog and summary screen (SPEC D3, D10).
                Button("Finish") { workout.finish() }
            }
        }
        .font(.title)
        .tint(.white)
    }
}

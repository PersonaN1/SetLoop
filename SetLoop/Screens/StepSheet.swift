import SetLoopCore
import SwiftUI

/// Step sheet: name, type, duration (DESIGN V2 type list; SPEC D18 range 0:01–99:59).
struct StepSheet: View {
    enum Result {
        case save(Step)
        case delete
    }

    @Environment(\.dismiss) private var dismiss
    let editing: StepEditing
    let colors: StepColors
    let onFinish: (Result) -> Void

    @State private var step: Step
    @State private var confirmingDelete = false

    init(editing: StepEditing, colors: StepColors, onFinish: @escaping (Result) -> Void) {
        self.editing = editing
        self.colors = colors
        self.onFinish = onFinish
        _step = State(initialValue: editing.step)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $step.name)
                        .submitLabel(.done)
                        .nameLimit($step.name)
                }
                if !editing.slot.fixedType {
                    Section("Type") {
                        ForEach(StepType.allCases, id: \.self) { type in
                            Button { select(type) } label: {
                                HStack(spacing: 12) {
                                    TypeDot(color: colors[type].color)
                                    Text(type.title).foregroundStyle(Color.primary)
                                    Spacer()
                                    if type == step.type {
                                        Image(systemName: "checkmark").fontWeight(.semibold)
                                    }
                                }
                            }
                            .accessibilityAddTraits(type == step.type ? .isSelected : [])
                        }
                    }
                }
                Section("Duration") {
                    DurationPicker(seconds: $step.duration)
                }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle("Step")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    if editing.isNew {
                        Button("Cancel") { dismiss() }
                    } else {
                        Button("Delete", role: .destructive) { confirmingDelete = true }
                            .tint(.red)
                            .confirmationDialog("Delete this step?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                                Button("Delete", role: .destructive) { onFinish(.delete) }
                            }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { finish() }.fontWeight(.semibold)
                }
            }
        }
    }

    /// A default name follows the type; a name the user typed stays.
    private func select(_ type: StepType) {
        let trimmed = step.name.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty || trimmed == step.type.defaultStepName {
            step.name = type.defaultStepName
        }
        step.type = type
    }

    private func finish() {
        var result = step
        let trimmed = result.name.trimmingCharacters(in: .whitespacesAndNewlines)
        result.name = trimmed.isEmpty ? result.type.defaultStepName : trimmed
        onFinish(.save(result))
    }
}

/// Minutes and seconds wheels, 0:01–99:59.
struct DurationPicker: View {
    @Binding var seconds: Int

    var body: some View {
        HStack(spacing: 0) {
            Picker("Minutes", selection: part(\.minutes)) {
                ForEach(0...99, id: \.self) { Text("\($0)").tag($0) }
            }
            .pickerStyle(.wheel)
            Text("min").padding(.trailing)
            Picker("Seconds", selection: part(\.seconds)) {
                ForEach(0...59, id: \.self) { Text(String(format: "%02d", $0)).tag($0) }
            }
            .pickerStyle(.wheel)
            Text("sec")
        }
        .frame(height: 160)
        .accessibilityElement(children: .contain)
    }

    private struct Parts {
        var minutes: Int
        var seconds: Int
    }

    private func part(_ keyPath: WritableKeyPath<Parts, Int>) -> Binding<Int> {
        Binding(
            get: { Parts(minutes: seconds / 60, seconds: seconds % 60)[keyPath: keyPath] },
            set: { newValue in
                var parts = Parts(minutes: seconds / 60, seconds: seconds % 60)
                parts[keyPath: keyPath] = newValue
                let total = parts.minutes * 60 + parts.seconds
                seconds = min(max(total, Limits.stepDuration.lowerBound), Limits.stepDuration.upperBound)
            }
        )
    }
}

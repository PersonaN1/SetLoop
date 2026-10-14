import SetLoopCore
import SwiftData
import SwiftUI

/// Timer editor sheet (SPEC D1, D2, D18; TECH T5): works on a copy, writes only on Done.
struct TimerEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Environment(WorkoutController.self) private var workout

    /// nil creates a new timer.
    let timer: SavedTimer?
    private let originalName: String
    private let original: TimerDefinition

    @State private var name: String
    @FocusState private var nameFocused: Bool
    @State private var draft: TimerDefinition
    @State private var editing: StepEditing?
    @State private var editMode = EditMode.inactive
    @State private var selection = Set<UUID>()
    @State private var mergeError: TimerDefinition.MergeError?
    @State private var confirmingDiscard = false

    init(timer: SavedTimer?) {
        self.timer = timer
        let definition = timer?.definition ?? Self.newDefinition()
        originalName = timer?.name ?? ""
        original = definition
        _name = State(initialValue: originalName)
        _draft = State(initialValue: definition)
    }

    private var hasChanges: Bool { name != originalName || draft != original }

    private var cleaned: TimerDefinition {
        var result = draft
        result.removeEmptyBlocks()
        return result
    }

    private var validationError: TimerDefinition.ValidationError? {
        do throws(TimerDefinition.ValidationError) {
            try cleaned.validate()
            return nil
        } catch {
            return error
        }
    }

    private var isValid: Bool { validationError == nil }

    var body: some View {
        NavigationStack {
            List(selection: $selection) {
                Section {
                    // An empty name falls back to the numbered default shown as the prompt.
                    TextField("Name", text: $name, prompt: Text("New Timer"))
                        // Return reads "Done" and closes the keyboard.
                        .submitLabel(.done)
                        .focused($nameFocused)
                        .nameLimit($name)
                }
                general
                ForEach(draft.blocks) { block in
                    blockSection(block)
                }
                Section {
                    Button("Add Block", systemImage: "plus") { addBlock() }
                        .disabled(draft.blocks.count >= Limits.maxBlocks)
                } footer: {
                    if draft.blocks.count >= Limits.maxBlocks {
                        Text("Up to \(Limits.maxBlocks) blocks in a timer.")
                    }
                }
                finish
            }
            .environment(\.editMode, $editMode)
            .safeAreaInset(edge: .bottom) {
                // Over the keyboard the panel would cover half the screen.
                if !nameFocused { bottomPanel }
            }
            .scrollDismissesKeyboard(.immediately)
            .navigationTitle(timer == nil ? "New Timer" : "Edit Timer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges { confirmingDiscard = true } else { dismiss() }
                    }
                    .confirmationDialog("Discard changes?", isPresented: $confirmingDiscard, titleVisibility: .visible) {
                        Button("Discard Changes", role: .destructive) { dismiss() }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .sheet(item: $editing) { item in
                StepSheet(editing: item, colors: workout.colors) { apply($0) }
            }
            .alert(mergeErrorTitle, isPresented: Binding(get: { mergeError != nil }, set: { if !$0 { mergeError = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(mergeErrorMessage)
            }
        }
        .interactiveDismissDisabled(hasChanges)
    }

    // MARK: Sections

    private var general: some View {
        Section("General") {
            optionalStep(draft.prepare, slot: .prepare, addTitle: "Add Prepare")
            HStack {
                Text("Sets")
                Spacer()
                Text("× \(draft.sets)").foregroundStyle(.secondary).monospacedDigit()
                Stepper("Sets", value: $draft.sets, in: Limits.repeats).labelsHidden()
            }
            if draft.sets > 1 {
                optionalStep(draft.restBetweenSets, slot: .restBetweenSets, addTitle: "Add Rest Between Sets")
            }
        }
    }

    private var finish: some View {
        Section {
            optionalStep(draft.cooldown, slot: .cooldown, addTitle: "Add Cooldown")
            Toggle("Skip Last Rest", isOn: $draft.skipLastRest)
        } header: {
            Text("Finish")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Removes only the rest at the very end of the workout. Rest between blocks and sets stays.")
                // The reason Done is disabled, which is otherwise hard to guess.
                if validationError == .emptyPlan {
                    Text("Nothing to run: the only step is the last rest, which is skipped.")
                        .foregroundStyle(.red)
                }
            }
        }
    }

    private func blockSection(_ block: Block) -> some View {
        let index = draft.blocks.firstIndex { $0.id == block.id } ?? 0
        return Section {
            HStack {
                Text("Cycles")
                Spacer()
                Text("× \(block.repeats)").foregroundStyle(.secondary).monospacedDigit()
                Stepper("Cycles", value: blockBinding(block.id).repeats, in: Limits.repeats).labelsHidden()
            }
            // Rows inside the blocks' ForEach inherit the block ID as a tag; only steps are selectable.
            .selectionDisabled()
            ForEach(block.steps) { step in
                stepRow(step, slot: .block(block.id, step.id))
                    // Select mode is for merging; delete markers would only get in the way.
                    .deleteDisabled(editMode.isEditing)
            }
            .onMove { from, to in mutateBlock(block.id) { $0.steps.move(fromOffsets: from, toOffset: to) } }
            .onDelete { offsets in mutateBlock(block.id) { $0.steps.remove(atOffsets: offsets) } }
            Button("Add Step", systemImage: "plus") {
                editing = StepEditing(slot: .block(block.id, nil),
                                      step: .next(after: block.steps.last) { $0.defaultStepName },
                                      isNew: true)
            }
            .disabled(block.steps.count >= Limits.maxStepsPerBlock)
            .selectionDisabled()
        } header: {
            HStack {
                Text("Block \(index + 1)")
                Spacer()
                Menu {
                    Button("Duplicate Block", systemImage: "plus.square.on.square") { duplicateBlock(block) }
                        .disabled(draft.blocks.count >= Limits.maxBlocks)
                    Button("Delete Block", systemImage: "trash", role: .destructive) {
                        draft.blocks.removeAll { $0.id == block.id }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle").imageScale(.large)
                }
                // The header uppercases its text, menu items included.
                .textCase(nil)
                .accessibilityLabel("Block \(index + 1) Options")
            }
        } footer: {
            if block.steps.count >= Limits.maxStepsPerBlock {
                Text("Up to \(Limits.maxStepsPerBlock) steps in a block.")
            }
        }
    }

    @ViewBuilder
    private func optionalStep(_ step: Step?, slot: StepSlot, addTitle: LocalizedStringKey) -> some View {
        if let step {
            stepRow(step, slot: slot)
                // Only block steps take part in selection.
                .selectionDisabled()
        } else {
            Button(addTitle, systemImage: "plus") {
                editing = StepEditing(slot: slot, step: slot.newStep, isNew: true)
            }
        }
    }

    @ViewBuilder
    private func stepRow(_ step: Step, slot: StepSlot) -> some View {
        let label = HStack(spacing: 12) {
            TypeDot(color: workout.colors[step.type].color)
            Text(step.name).foregroundStyle(Color.primary)
            Spacer()
            Text(WorkoutFormat.duration(step.duration)).foregroundStyle(.secondary).monospacedDigit()
        }
        if editMode.isEditing {
            label
        } else {
            Button { editing = StepEditing(slot: slot, step: step) } label: { label }
                // Keeps the duration gray instead of tinted.
                .tint(.primary)
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Total").foregroundStyle(.secondary)
                Spacer()
                Text(WorkoutFormat.duration(cleaned.totalDuration)).fontWeight(.semibold).monospacedDigit()
            }
            .font(.subheadline)
            TimerStrip(definition: cleaned, colors: workout.colors, height: 8)
            HStack {
                Button(editMode.isEditing ? "Cancel" : "Select Steps") {
                    withAnimation {
                        editMode = editMode.isEditing ? .inactive : .active
                        selection = []
                    }
                }
                Spacer()
                if editMode.isEditing {
                    Button("Merge into Block") { merge() }
                        .fontWeight(.semibold)
                        .disabled(selection.isEmpty)
                }
            }
            .frame(minHeight: 44)
        }
        .padding(.horizontal)
        .padding(.top, 10)
        .background(.bar)
    }

    // MARK: Editing

    private func apply(_ result: StepSheet.Result) {
        guard let item = editing else { return }
        editing = nil
        let step: Step? = if case .save(let step) = result { step } else { nil }
        switch item.slot {
        case .prepare: draft.prepare = step
        case .restBetweenSets: draft.restBetweenSets = step
        case .cooldown: draft.cooldown = step
        case .block(let blockID, let stepID):
            mutateBlock(blockID) { block in
                if let stepID, let index = block.steps.firstIndex(where: { $0.id == stepID }) {
                    if let step { block.steps[index] = step } else { block.steps.remove(at: index) }
                } else if let step {
                    block.steps.append(step)
                }
            }
        }
    }

    private func blockBinding(_ id: UUID) -> Binding<Block> {
        Binding(
            get: { draft.blocks.first { $0.id == id } ?? Block(steps: []) },
            set: { newValue in mutateBlock(id) { $0 = newValue } }
        )
    }

    private func mutateBlock(_ id: UUID, _ change: (inout Block) -> Void) {
        guard let index = draft.blocks.firstIndex(where: { $0.id == id }) else { return }
        change(&draft.blocks[index])
    }

    private func addBlock() {
        let names: (StepType) -> String = { $0.defaultStepName }
        let work = Step.next(after: nil, names: names)
        draft.blocks.append(Block(steps: [work, .next(after: work, names: names)]))
    }

    private func duplicateBlock(_ block: Block) {
        guard let index = draft.blocks.firstIndex(where: { $0.id == block.id }) else { return }
        let copy = Block(steps: block.steps.map { Step(name: $0.name, duration: $0.duration, type: $0.type) },
                         repeats: block.repeats)
        draft.blocks.insert(copy, at: index + 1)
    }

    private func merge() {
        do {
            try draft.mergeIntoBlock(stepIDs: selection)
            withAnimation {
                editMode = .inactive
                selection = []
            }
        } catch {
            mergeError = error
        }
    }

    private var mergeErrorTitle: String {
        switch mergeError {
        case .tooManyBlocks: String(localized: "Too many blocks")
        default: String(localized: "Can't merge these steps")
        }
    }

    private var mergeErrorMessage: String {
        switch mergeError {
        case .notContiguous: String(localized: "Select neighboring steps of one block.")
        case .wholeBlock: String(localized: "These steps already form a block. Change its cycles instead.")
        case .tooManyBlocks: String(localized: "A timer can have up to \(Limits.maxBlocks) blocks.")
        case nil: ""
        }
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let others = ((try? context.fetch(FetchDescriptor<SavedTimer>())) ?? [])
            .filter { $0 !== timer }
            .map(\.name)
        let finalName = trimmed.isEmpty
            ? TimerNaming.unique(String(localized: "New Timer"), among: others)
            : trimmed
        if let timer {
            timer.name = finalName
            timer.definition = cleaned
        } else {
            var last = FetchDescriptor<SavedTimer>(sortBy: [SortDescriptor(\.sortIndex, order: .reverse)])
            last.fetchLimit = 1
            let sortIndex = ((try? context.fetch(last))?.first?.sortIndex ?? -1) + 1
            context.insert(SavedTimer(name: finalName, definition: cleaned, sortIndex: sortIndex))
        }
        context.saveOrReport()
        dismiss()
    }

    private static func newDefinition() -> TimerDefinition {
        TimerDefinition(
            prepare: StepSlot.prepare.newStep,
            blocks: [Block(steps: [
                Step(name: StepType.workA.defaultStepName, duration: 30, type: .workA),
                Step(name: StepType.rest.defaultStepName, duration: 15, type: .rest),
            ], repeats: 3)]
        )
    }
}

/// Where an edited step lives in the definition.
enum StepSlot: Equatable {
    case prepare, restBetweenSets, cooldown
    /// A nil step ID appends a new step to the block.
    case block(UUID, UUID?)

    /// Prepare, cooldown and rest between sets have a fixed type.
    var fixedType: Bool { if case .block = self { false } else { true } }

    var newStep: Step {
        switch self {
        case .prepare: Step(name: StepType.prepare.defaultStepName, duration: 10, type: .prepare)
        case .restBetweenSets: Step(name: String(localized: "Rest between sets"), duration: 60, type: .rest)
        case .cooldown: Step(name: StepType.cooldown.defaultStepName, duration: 60, type: .cooldown)
        case .block: Step(name: StepType.workA.defaultStepName, duration: 20, type: .workA)
        }
    }
}

struct StepEditing: Identifiable {
    let slot: StepSlot
    var step: Step
    /// Not in the definition yet: the sheet offers Cancel instead of Delete.
    var isNew = false
    var id: UUID { step.id }
}

import SwiftData
import SwiftUI

/// iOS-style bulk delete for a list: Select / Done, Select All, Delete (N) with confirmation.
/// Swipe-to-delete on a row can reuse the same confirmation by setting `pendingDelete`.
struct SelectionToolbar: ViewModifier {
    @Binding var editMode: EditMode
    @Binding var selection: Set<PersistentIdentifier>
    /// Items waiting for confirmation; nil when nothing is pending.
    @Binding var pendingDelete: Set<PersistentIdentifier>?
    let allIDs: [PersistentIdentifier]
    let confirmationTitle: (Int) -> Text
    let delete: (Set<PersistentIdentifier>) -> Void

    func body(content: Content) -> some View {
        content
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(editMode.isEditing ? "Done" : "Select") { setEditing(!editMode.isEditing) }
                        .disabled(allIDs.isEmpty && !editMode.isEditing)
                }
                if editMode.isEditing {
                    ToolbarItem(placement: .topBarLeading) {
                        let allSelected = !allIDs.isEmpty && selection.count == allIDs.count
                        Button(allSelected ? "Deselect All" : "Select All") {
                            selection = allSelected ? [] : Set(allIDs)
                        }
                    }
                    ToolbarItem(placement: .bottomBar) {
                        Button(role: .destructive) {
                            pendingDelete = selection
                        } label: {
                            Text("Delete (\(selection.count))")
                        }
                        .disabled(selection.isEmpty)
                    }
                }
            }
            .confirmationDialog(
                confirmationTitle(pendingDelete?.count ?? 0),
                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                titleVisibility: .visible,
                presenting: pendingDelete
            ) { ids in
                Button("Delete", role: .destructive) {
                    delete(ids)
                    selection.subtract(ids)
                    if allIDs.count == ids.count { setEditing(false) }
                }
            }
            .onChange(of: allIDs) { selection.formIntersection($1) }
            // Set last so the list and everything around it share one edit mode.
            .environment(\.editMode, $editMode)
    }

    private func setEditing(_ editing: Bool) {
        withAnimation {
            editMode = editing ? .active : .inactive
            selection = []
        }
    }
}

extension View {
    func selectionToolbar(
        editMode: Binding<EditMode>,
        selection: Binding<Set<PersistentIdentifier>>,
        pendingDelete: Binding<Set<PersistentIdentifier>?>,
        allIDs: [PersistentIdentifier],
        confirmationTitle: @escaping (Int) -> Text,
        delete: @escaping (Set<PersistentIdentifier>) -> Void
    ) -> some View {
        modifier(SelectionToolbar(
            editMode: editMode, selection: selection, pendingDelete: pendingDelete,
            allIDs: allIDs, confirmationTitle: confirmationTitle, delete: delete
        ))
    }
}

extension ModelContext {
    func delete(ids: Set<PersistentIdentifier>) {
        for id in ids { delete(model(for: id)) }
        try? save()
    }
}

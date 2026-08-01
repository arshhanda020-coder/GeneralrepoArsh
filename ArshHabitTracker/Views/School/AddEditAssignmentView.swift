//
//  AddEditAssignmentView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct AddEditAssignmentView: View {
    let assignment: Assignment?
    /// Only used when creating a new assignment — it's added under this topic.
    var presetTopic: Topic?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hasDueDate = true
    @State private var dueDate = Date()
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignment") {
                    TextField("Title", text: $title)
                    Toggle("Has a due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                    }
                }
                Section("Notes") {
                    TextField("Anything else", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if assignment != nil {
                    Section {
                        Button("Delete assignment", role: .destructive) { deleteAssignment() }
                    }
                }
            }
            .navigationTitle(assignment == nil ? "New Assignment" : "Edit Assignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: populateIfEditing)
        }
    }

    private func populateIfEditing() {
        guard let assignment else { return }
        title = assignment.title
        notes = assignment.notes ?? ""
        if let due = assignment.dueDate {
            hasDueDate = true
            dueDate = due
        } else {
            hasDueDate = false
        }
    }

    private func save() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let assignment {
            assignment.title = title
            assignment.dueDate = hasDueDate ? dueDate : nil
            assignment.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            let newAssignment = Assignment(
                title: title,
                dueDate: hasDueDate ? dueDate : nil,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                topic: presetTopic
            )
            modelContext.insert(newAssignment)
        }
        dismiss()
    }

    private func deleteAssignment() {
        if let assignment {
            modelContext.delete(assignment)
        }
        dismiss()
    }
}

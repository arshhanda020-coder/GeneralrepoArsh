//
//  AddEditProjectTaskView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct AddEditProjectTaskView: View {
    @Bindable var task: ProjectTask

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var hasDueDate = false
    @State private var dueDate = Date()
    @State private var remindersOn = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Task") {
                    TextField("Title", text: $title)
                    Toggle("Has a due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                        Toggle("Remind me", isOn: $remindersOn)
                    }
                }
                Section {
                    Button("Delete task", role: .destructive) { deleteTask() }
                }
            }
            .navigationTitle("Edit Task")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                title = task.title
                if let due = task.dueDate {
                    hasDueDate = true
                    dueDate = due
                }
                remindersOn = task.remindersOn
            }
            .onSubmit {
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                save()
            }
        }
    }

    private func save() {
        task.title = title
        task.dueDate = hasDueDate ? dueDate : nil
        task.remindersOn = hasDueDate && remindersOn
        NotificationManager.shared.sync(projectTask: task)
        dismiss()
    }

    private func deleteTask() {
        NotificationManager.shared.cancelOneOff(identifier: "project-task-\(task.id)")
        modelContext.delete(task)
        dismiss()
    }
}

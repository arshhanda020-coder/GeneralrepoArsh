//
//  AddEditAssignmentView.swift
//  Odysseus
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
    @State private var remindersOn = false
    @State private var useSpecificTime = false
    @State private var reminderTime = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignment") {
                    TextField("Title", text: $title)
                    Toggle("Has a due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                        Toggle("Remind me", isOn: $remindersOn)
                        if remindersOn {
                            Toggle("At a specific time", isOn: $useSpecificTime)
                            if useSpecificTime {
                                DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                            } else {
                                Text("Reminder fires at 9am on the due date.")
                                    .font(.caption)
                                    .foregroundStyle(Theme.dimText)
                            }
                        }
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
            .onAppear(perform: populateIfEditing)
            .onSubmit {
                guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                save()
            }
        }
    }

    private func populateIfEditing() {
        guard let assignment else { return }
        title = assignment.title
        notes = assignment.notes ?? ""
        remindersOn = assignment.remindersOn
        if let due = assignment.dueDate {
            hasDueDate = true
            dueDate = due
            let comps = Calendar.current.dateComponents([.hour, .minute], from: due)
            if comps.hour != 0 || comps.minute != 0 {
                useSpecificTime = true
                reminderTime = due
            }
        } else {
            hasDueDate = false
        }
    }

    /// Date-only picker UI can leave a stray time-of-day on `dueDate` (it
    /// only ever edits the day, never resets the time), so this always
    /// re-anchors to midnight unless the user explicitly opted into a
    /// specific reminder time — otherwise NotificationManager would fire at
    /// whatever incidental time this sheet happened to be opened.
    private func resolvedDueDate() -> Date {
        let dayOnly = Calendar.current.startOfDay(for: dueDate)
        guard remindersOn, useSpecificTime else { return dayOnly }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: dayOnly)
        let timeComps = Calendar.current.dateComponents([.hour, .minute], from: reminderTime)
        comps.hour = timeComps.hour
        comps.minute = timeComps.minute
        return Calendar.current.date(from: comps) ?? dayOnly
    }

    private func save() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedDate = hasDueDate ? resolvedDueDate() : nil
        let targetAssignment: Assignment
        if let assignment {
            assignment.title = title
            assignment.dueDate = resolvedDate
            assignment.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            assignment.remindersOn = hasDueDate && remindersOn
            targetAssignment = assignment
        } else {
            let newAssignment = Assignment(
                title: title,
                dueDate: resolvedDate,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                topic: presetTopic,
                remindersOn: hasDueDate && remindersOn
            )
            modelContext.insert(newAssignment)
            targetAssignment = newAssignment
        }
        NotificationManager.shared.sync(assignment: targetAssignment)
        if hasDueDate, remindersOn {
            NotificationManager.shared.notifyReminderSet(title: title, date: dueDate)
        }
        dismiss()
    }

    private func deleteAssignment() {
        if let assignment {
            NotificationManager.shared.cancelReminders(assignmentID: assignment.id)
            modelContext.delete(assignment)
        }
        dismiss()
    }
}

//
//  AddEditLessonView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct AddEditLessonView: View {
    let lesson: Lesson?
    /// Only used when creating a new lesson — it's added under this topic.
    var presetTopic: Topic?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Lesson") {
                    TextField("Title", text: $title)
                }
                Section("Notes") {
                    TextField("Anything else", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if lesson != nil {
                    Section {
                        Button("Delete lesson", role: .destructive) { deleteLesson() }
                    }
                }
            }
            .navigationTitle(lesson == nil ? "New Lesson" : "Edit Lesson")
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
        }
    }

    private func populateIfEditing() {
        guard let lesson else { return }
        title = lesson.title
        notes = lesson.notes ?? ""
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let lesson {
            lesson.title = trimmedTitle
            lesson.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            let nextIndex = ((presetTopic?.lessons.map(\.sortIndex).max()) ?? -1) + 1
            modelContext.insert(Lesson(
                title: trimmedTitle,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                sortIndex: nextIndex,
                topic: presetTopic
            ))
        }
        dismiss()
    }

    private func deleteLesson() {
        if let lesson {
            modelContext.delete(lesson)
        }
        dismiss()
    }
}

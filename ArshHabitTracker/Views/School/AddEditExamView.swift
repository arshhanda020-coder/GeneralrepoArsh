//
//  AddEditExamView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct AddEditExamView: View {
    let exam: Exam?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var examDate = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var targetScore = ""
    @State private var notes = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Exam") {
                    TextField("Name (e.g. March SAT, AP Chemistry)", text: $name)
                    DatePicker("Date", selection: $examDate, displayedComponents: .date)
                }
                Section("Goal") {
                    TextField("Target score (optional)", text: $targetScore)
                }
                Section("Notes") {
                    TextField("Anything else", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }
                if exam != nil {
                    Section {
                        Button("Delete exam", role: .destructive) { deleteExam() }
                    }
                }
            }
            .navigationTitle(exam == nil ? "New Exam" : "Edit Exam")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: populateIfEditing)
        }
    }

    private func populateIfEditing() {
        guard let exam else { return }
        name = exam.name
        examDate = exam.examDate
        targetScore = exam.targetScore ?? ""
        notes = exam.notes ?? ""
    }

    private func save() {
        let trimmedTarget = targetScore.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exam {
            exam.name = name
            exam.examDate = examDate
            exam.targetScore = trimmedTarget.isEmpty ? nil : trimmedTarget
            exam.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            let newExam = Exam(
                name: name,
                examDate: examDate,
                targetScore: trimmedTarget.isEmpty ? nil : trimmedTarget,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes
            )
            modelContext.insert(newExam)
        }
        dismiss()
    }

    private func deleteExam() {
        if let exam {
            modelContext.delete(exam)
        }
        dismiss()
    }
}

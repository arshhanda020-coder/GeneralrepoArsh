//
//  LogStudySessionSheet.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct LogStudySessionSheet: View {
    let exam: Exam

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var subjectArea = "General"
    @State private var durationText = ""

    private let actSubjects = ["General", "English", "Math", "Reading", "Science"]

    var body: some View {
        NavigationStack {
            Form {
                if exam.category == .act {
                    Section("Section") {
                        Picker("Section", selection: $subjectArea) {
                            ForEach(actSubjects, id: \.self) { subject in
                                Text(subject).tag(subject)
                            }
                        }
                    }
                }
                Section("Duration (minutes, optional)") {
                    TextField("e.g. 45", text: $durationText)
                        .platformKeyboardType(.numberPad)
                }
                Section("Session note (optional)") {
                    TextField("What did you study?", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Log study session")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onSubmit { save() }
        }
        .presentationDetents([.medium])
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(StudySession(
            date: .now,
            note: trimmed.isEmpty ? nil : trimmed,
            subjectArea: exam.category == .act ? subjectArea : nil,
            durationMinutes: Int(durationText),
            exam: exam
        ))
        dismiss()
    }
}

//
//  LogStudySessionSheet.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct LogStudySessionSheet: View {
    let exam: Exam

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Session note (optional)") {
                    TextField("What did you study?", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("Log study session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
                        modelContext.insert(StudySession(date: .now, note: trimmed.isEmpty ? nil : trimmed, exam: exam))
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

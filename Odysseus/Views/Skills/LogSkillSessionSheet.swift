//
//  LogSkillSessionSheet.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct LogSkillSessionSheet: View {
    let skill: Skill

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var note: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Session note (optional)") {
                    TextField("What did you work on?", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
            }
            .navigationTitle("\(skill.emoji) Log session")
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
        let session = SkillSession(date: .now, note: trimmed.isEmpty ? nil : trimmed, skill: skill)
        modelContext.insert(session)
        dismiss()
    }
}

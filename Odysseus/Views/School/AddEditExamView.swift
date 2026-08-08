//
//  AddEditExamView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct AddEditExamView: View {
    let exam: Exam?
    var presetCategory: ExamCategory?
    /// Only used when creating a new exam — it's linked to this class so it
    /// shows up in that class's page too.
    var presetClass: SchoolClass?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SchoolClass.sortIndex) private var schoolClasses: [SchoolClass]

    @State private var name = ""
    @State private var examDate = Date().addingTimeInterval(60 * 60 * 24 * 30)
    @State private var targetScore = ""
    @State private var notes = ""
    @State private var category: ExamCategory = .marchExams
    @State private var actualScore = ""
    @State private var linkedClass: SchoolClass?

    var body: some View {
        NavigationStack {
            Form {
                Section("Exam") {
                    TextField("Name (e.g. March SAT, AP Chemistry)", text: $name)
                    DatePicker("Date", selection: $examDate, displayedComponents: .date)
                    Picker("Category", selection: $category) {
                        ForEach(ExamCategory.allCases, id: \.self) { cat in
                            Text(cat.displayName).tag(cat)
                        }
                    }
                    Picker("Class", selection: $linkedClass) {
                        Text("None").tag(nil as SchoolClass?)
                        ForEach(schoolClasses) { schoolClass in
                            Text(schoolClass.name).tag(schoolClass as SchoolClass?)
                        }
                    }
                }
                Section("Goal") {
                    TextField("Target score (optional)", text: $targetScore)
                }
                Section("Score") {
                    TextField("Actual score, once you have it", text: $actualScore)
                    if !actualScore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text("Logging a score marks this test as scored — it'll show up in your GPA/score history.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    }
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
            .inlineNavigationTitle()
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
            .onSubmit {
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                save()
            }
        }
    }

    private func populateIfEditing() {
        if let presetCategory, exam == nil {
            category = presetCategory
        }
        if let presetClass, exam == nil {
            linkedClass = presetClass
        }
        guard let exam else { return }
        name = exam.name
        examDate = exam.examDate
        targetScore = exam.targetScore ?? ""
        notes = exam.notes ?? ""
        category = exam.category
        actualScore = exam.actualScore ?? ""
        linkedClass = exam.schoolClass
    }

    private func save() {
        let trimmedTarget = targetScore.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedScore = actualScore.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exam {
            let hadScore = exam.hasScore
            exam.name = name
            exam.examDate = examDate
            exam.targetScore = trimmedTarget.isEmpty ? nil : trimmedTarget
            exam.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            exam.category = category
            exam.schoolClass = linkedClass
            exam.actualScore = trimmedScore.isEmpty ? nil : trimmedScore
            if !hadScore, !trimmedScore.isEmpty {
                exam.scoreLoggedAt = .now
            } else if trimmedScore.isEmpty {
                exam.scoreLoggedAt = nil
            }
        } else {
            let newExam = Exam(
                name: name,
                examDate: examDate,
                targetScore: trimmedTarget.isEmpty ? nil : trimmedTarget,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                schoolClass: linkedClass,
                category: category,
                actualScore: trimmedScore.isEmpty ? nil : trimmedScore,
                scoreLoggedAt: trimmedScore.isEmpty ? nil : .now
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

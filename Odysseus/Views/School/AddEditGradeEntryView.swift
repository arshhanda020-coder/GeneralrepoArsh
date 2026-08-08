//
//  AddEditGradeEntryView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct AddEditGradeEntryView: View {
    let entry: GradeEntry?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \GradeScaleEntry.sortIndex) private var scaleEntries: [GradeScaleEntry]

    @State private var courseName = ""
    @State private var gradeLabel = ""
    @State private var credits = "1.0"
    @State private var isWeighted = false
    @State private var term = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Class") {
                    TextField("Course name", text: $courseName)
                    TextField("Term (optional)", text: $term)
                }
                Section("Grade") {
                    if scaleEntries.isEmpty {
                        TextField("Grade (e.g. A, B+)", text: $gradeLabel)
                        Text("Add scale entries first so this resolves to GPA points.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    } else {
                        Picker("Grade", selection: $gradeLabel) {
                            Text("Select").tag("")
                            ForEach(scaleEntries) { entry in
                                Text(entry.label).tag(entry.label)
                            }
                        }
                    }
                    TextField("Credits", text: $credits)
                        .platformKeyboardType(.decimalPad)
                    Toggle("Honors/AP (weighted)", isOn: $isWeighted)
                }
                if entry != nil {
                    Section {
                        Button("Delete", role: .destructive) { deleteEntry() }
                    }
                }
            }
            .navigationTitle(entry == nil ? "New Grade" : "Edit Grade")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || gradeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: populateIfEditing)
            .onSubmit {
                guard !courseName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                      !gradeLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                save()
            }
        }
    }

    private func populateIfEditing() {
        guard let entry else { return }
        courseName = entry.courseName
        gradeLabel = entry.gradeLabel
        credits = String(entry.credits)
        isWeighted = entry.isWeighted
        term = entry.term ?? ""
    }

    private func save() {
        let trimmedTerm = term.trimmingCharacters(in: .whitespacesAndNewlines)
        let creditsValue = Double(credits) ?? 1.0
        if let entry {
            entry.courseName = courseName
            entry.gradeLabel = gradeLabel
            entry.credits = creditsValue
            entry.isWeighted = isWeighted
            entry.term = trimmedTerm.isEmpty ? nil : trimmedTerm
        } else {
            let newEntry = GradeEntry(
                courseName: courseName,
                gradeLabel: gradeLabel,
                credits: creditsValue,
                isWeighted: isWeighted,
                term: trimmedTerm.isEmpty ? nil : trimmedTerm
            )
            modelContext.insert(newEntry)
            NotificationManager.shared.notifyGradeAdded(course: courseName, gradeLabel: gradeLabel)
        }
        dismiss()
    }

    private func deleteEntry() {
        if let entry {
            modelContext.delete(entry)
        }
        dismiss()
    }
}

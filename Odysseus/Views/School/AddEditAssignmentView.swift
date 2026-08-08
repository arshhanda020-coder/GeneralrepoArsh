//
//  AddEditAssignmentView.swift
//  Odysseus
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddEditAssignmentView: View {
    let assignment: Assignment?
    /// Only used when creating a new assignment — it's added under this topic.
    var presetTopic: Topic?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var type: AssignmentType = .assignment
    @State private var hasDueDate = true
    @State private var dueDate = Date()
    @State private var notes = ""
    @State private var remindersOn = false
    @State private var pointsEarned = ""
    @State private var pointsPossible = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Assignment") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $type) {
                        ForEach(AssignmentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    Toggle("Has a due date", isOn: $hasDueDate)
                    if hasDueDate {
                        DatePicker("Due", selection: $dueDate, displayedComponents: .date)
                        Toggle("Remind me", isOn: $remindersOn)
                    }
                }
                Section("Score") {
                    HStack {
                        TextField("Points earned", text: $pointsEarned)
                            .platformKeyboardType(.decimalPad)
                        Text("/")
                            .foregroundStyle(Theme.dimText)
                        TextField("Points possible", text: $pointsPossible)
                            .platformKeyboardType(.decimalPad)
                    }
                    if let earned = Double(pointsEarned), let possible = Double(pointsPossible), possible > 0 {
                        Text("\(String(format: "%.0f%%", earned / possible * 100)) — counts toward this class's grade.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    } else {
                        Text("Leave blank until it's graded — both fields are needed for it to count toward the class grade.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    }
                }
                Section("Photo") {
                    Text("Optional — attach a photo of the assignment, rubric, or graded work if it helps you (or AI help) later.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                    if let photoData, let uiImage = PlatformImage(data: photoData) {
                        Image(platformImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    HStack {
                        PhotosPicker(selection: $photoItem, matching: .images) {
                            Label(photoData == nil ? "Add photo" : "Replace photo", systemImage: "camera")
                        }
                        if photoData != nil {
                            Spacer()
                            Button("Remove", role: .destructive) { photoData = nil; photoItem = nil }
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
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = PlatformImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                    }
                }
            }
        }
    }

    private func populateIfEditing() {
        guard let assignment else { return }
        title = assignment.title
        type = assignment.type
        notes = assignment.notes ?? ""
        remindersOn = assignment.remindersOn
        pointsEarned = assignment.pointsEarned.map { String($0) } ?? ""
        pointsPossible = assignment.pointsPossible.map { String($0) } ?? ""
        photoData = assignment.photoData
        if let due = assignment.dueDate {
            hasDueDate = true
            dueDate = due
        } else {
            hasDueDate = false
        }
    }

    private func save() {
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let earned = Double(pointsEarned)
        let possible = Double(pointsPossible)
        // Both fields have to resolve for it to count toward the class grade.
        let resolvedEarned = (earned != nil && possible != nil) ? earned : nil
        let resolvedPossible = (earned != nil && possible != nil) ? possible : nil
        let targetAssignment: Assignment
        if let assignment {
            assignment.title = title
            assignment.type = type
            assignment.dueDate = hasDueDate ? dueDate : nil
            assignment.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
            assignment.remindersOn = hasDueDate && remindersOn
            assignment.pointsEarned = resolvedEarned
            assignment.pointsPossible = resolvedPossible
            assignment.photoData = photoData
            targetAssignment = assignment
        } else {
            let newAssignment = Assignment(
                title: title,
                dueDate: hasDueDate ? dueDate : nil,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                topic: presetTopic,
                remindersOn: hasDueDate && remindersOn,
                type: type,
                pointsEarned: resolvedEarned,
                pointsPossible: resolvedPossible,
                photoData: photoData
            )
            modelContext.insert(newAssignment)
            targetAssignment = newAssignment
        }
        NotificationManager.shared.sync(assignment: targetAssignment)
        dismiss()
    }

    private func deleteAssignment() {
        if let assignment {
            NotificationManager.shared.cancelOneOff(identifier: "assignment-\(assignment.id)")
            modelContext.delete(assignment)
        }
        dismiss()
    }
}

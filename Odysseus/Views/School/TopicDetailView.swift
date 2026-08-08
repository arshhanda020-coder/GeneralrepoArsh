//
//  TopicDetailView.swift
//  Odysseus
//
//  Assignments for one topic, each with "I understand" / "Help me understand"
//  buttons, plus a direct line into Test Me scoped to this topic.
//

import SwiftUI
import SwiftData
import PhotosUI

struct TopicDetailView: View {
    @Bindable var topic: Topic

    @Environment(\.modelContext) private var modelContext
    @State private var newAssignmentTitle = ""
    @State private var editingAssignment: Assignment?
    @State private var explainingAssignment: Assignment?
    @State private var isExplaining = false
    @State private var explainError: String?
    /// Gates "Help understand" on a photo when none is attached yet — asked
    /// once per tap rather than silently skipping straight to a blind answer.
    @State private var promptingPhotoFor: Assignment?
    @State private var helpPhotoItem: PhotosPickerItem?

    private var pendingAssignments: [Assignment] { topic.assignments.filter { !$0.isDone } }
    private var doneAssignments: [Assignment] { topic.assignments.filter { $0.isDone } }

    /// Everything logged under this topic — assignments, quizzes, tests,
    /// projects, with notes and scores — so "Test me" quizzes on what's
    /// actually here instead of guessing from the topic name alone.
    private var loggedMaterialSummary: String {
        topic.assignments.map { assignment -> String in
            var line = "[\(assignment.type.displayName)] \(assignment.title)"
            line += assignment.isDone ? " (completed)" : " (pending)"
            if let percent = assignment.percentScore {
                line += " — scored \(String(format: "%.0f%%", percent))"
            }
            if let notes = assignment.notes, !notes.isEmpty {
                line += " — notes: \(notes)"
            }
            return line
        }.joined(separator: "\n")
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavigationLink(destination: TestMeView(presetSubject: topic.name, contextMaterial: loggedMaterialSummary)) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                        Text("Test me on \(topic.name)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .foregroundStyle(Theme.primaryText)
                    .padding(12)
                    .glassPanel(cornerRadius: 10, borderColor: MindMapSection.school.accentColor.opacity(0.7))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("ASSIGNMENTS")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.dimText)

                    HStack(spacing: 8) {
                        TextField("Add an assignment", text: $newAssignmentTitle)
                            .padding(10)
                            .glassPanel(cornerRadius: 8)
                            .onSubmit(addAssignment)
                        Button(action: addAssignment) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(newAssignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dimText : MindMapSection.school.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(newAssignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if topic.assignments.isEmpty {
                        Text("Nothing added yet — log homework, projects, or readings for this topic here.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array((pendingAssignments + doneAssignments).enumerated()), id: \.element.id) { index, assignment in
                                if index > 0 {
                                    Divider().overlay(Theme.cardBorder)
                                }
                                assignmentRow(assignment)
                            }
                        }
                        .glassPanel(cornerRadius: 10)
                    }
                }

                NotesSectionView(context: .topic(topic.id), accentColor: MindMapSection.school.accentColor)
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(topic.name)
        .inlineNavigationTitle()
        .sheet(item: $editingAssignment) { assignment in
            AddEditAssignmentView(assignment: assignment)
        }
        .confirmationDialog(
            "Add a photo of this first?",
            isPresented: Binding(get: { promptingPhotoFor != nil }, set: { if !$0 { promptingPhotoFor = nil } }),
            titleVisibility: .visible
        ) {
            PhotosPicker(selection: $helpPhotoItem, matching: .images) {
                Text("Add photo")
            }
            Button("Continue without a photo") {
                if let assignment = promptingPhotoFor { helpUnderstand(assignment) }
                promptingPhotoFor = nil
            }
            Button("Cancel", role: .cancel) { promptingPhotoFor = nil }
        } message: {
            Text("No photo attached yet — a photo of the assignment, question, or your work usually gets a much better answer.")
        }
        .onChange(of: helpPhotoItem) { _, newItem in
            guard let assignment = promptingPhotoFor else { return }
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    assignment.photoData = PlatformImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                }
                helpPhotoItem = nil
                promptingPhotoFor = nil
                helpUnderstand(assignment)
            }
        }
    }

    private func requestHelp(_ assignment: Assignment) {
        if assignment.photoData == nil {
            promptingPhotoFor = assignment
        } else {
            helpUnderstand(assignment)
        }
    }

    private func assignmentRow(_ assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        assignment.isDone.toggle()
                    }
                } label: {
                    Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(assignment.isDone ? MindMapSection.school.accentColor : Theme.dimText)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 5) {
                        Text(assignment.title)
                            .font(.subheadline)
                            .foregroundStyle(assignment.isDone ? Theme.dimText : Theme.primaryText)
                            .strikethrough(assignment.isDone)
                        if assignment.type != .assignment {
                            Text(assignment.type.displayName.uppercased())
                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                .foregroundStyle(MindMapSection.school.accentColor)
                        }
                    }
                    HStack(spacing: 6) {
                        if let due = assignment.dueDate {
                            Text(due.formatted(.dateTime.month(.abbreviated).day()))
                        }
                        if let earned = assignment.pointsEarned, let possible = assignment.pointsPossible, possible > 0 {
                            Text("\(earned.formatted())/\(possible.formatted()) (\(String(format: "%.0f%%", earned / possible * 100)))")
                        }
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
                }

                Spacer()

                if assignment.understood == true {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.terminalGreen)
                }
            }

            HStack(spacing: 8) {
                Button {
                    withAnimation { assignment.understood = true }
                } label: {
                    Label("I understand", systemImage: "checkmark.circle")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Theme.terminalGreen)

                Button {
                    requestHelp(assignment)
                } label: {
                    Label(
                        isExplaining && explainingAssignment?.id == assignment.id ? "Thinking…" : "Help understand",
                        systemImage: "sparkles"
                    )
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(MindMapSection.school.accentColor)
                .disabled(isExplaining && explainingAssignment?.id == assignment.id)
            }
            .font(.caption.weight(.semibold))
            .controlSize(.small)

            if explainingAssignment?.id == assignment.id, let error = explainError {
                Text(error).font(.caption).foregroundStyle(Theme.negative)
            }
            if let explanation = assignment.helpExplanation, assignment.understood == false {
                Divider().overlay(Theme.cardBorder)
                Text(explanation)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { editingAssignment = assignment }
    }

    private func addAssignment() {
        let trimmed = newAssignmentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        // Defaults to today so it shows up on the Calendar immediately —
        // edit the assignment afterward to push the date out or clear it.
        let assignment = Assignment(title: trimmed, dueDate: Date(), topic: topic)
        modelContext.insert(assignment)
        NotificationManager.shared.sync(assignment: assignment)
        newAssignmentTitle = ""
    }

    private func helpUnderstand(_ assignment: Assignment) {
        explainingAssignment = assignment
        isExplaining = true
        explainError = nil
        let className = topic.schoolClass.map { " (\($0.name))" } ?? ""
        let prompt = "Explain this assignment/topic so I actually understand it, step by step: \"\(assignment.title)\"\(className) under the topic \"\(topic.name)\"." + (assignment.notes.map { " Extra context: \($0)" } ?? "")

        Task {
            do {
                let explanation = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: assignment.photoData,
                    systemPrompt: "You are a patient, encouraging tutor. Explain concepts step by step so the student actually understands the reasoning, not just the answer. Keep it focused and not overly long."
                )
                assignment.helpExplanation = explanation
                assignment.understood = false
            } catch {
                explainError = error.localizedDescription
            }
            isExplaining = false
        }
    }
}

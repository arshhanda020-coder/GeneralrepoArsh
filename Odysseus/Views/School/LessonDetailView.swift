//
//  LessonDetailView.swift
//  Odysseus
//
//  A lesson's assignments, tests/quizzes, and materials — Google
//  Classroom–style, each added independently via the toolbar "+" menu.
//

import SwiftUI
import SwiftData

struct LessonDetailView: View {
    @Bindable var lesson: Lesson

    @Environment(\.modelContext) private var modelContext
    @State private var addingAssignment = false
    @State private var addingQuiz = false
    @State private var addingMaterial = false
    @State private var editingAssignment: Assignment?
    @State private var editingMaterial: LessonMaterial?
    @State private var explainingAssignment: Assignment?
    @State private var isExplaining = false
    @State private var explainError: String?

    private var pendingHomework: [Assignment] { lesson.homework.filter { !$0.isDone } }
    private var doneHomework: [Assignment] { lesson.homework.filter { $0.isDone } }
    private var pendingTests: [Assignment] { lesson.tests.filter { !$0.isDone } }
    private var doneTests: [Assignment] { lesson.tests.filter { $0.isDone } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                NavigationLink(destination: TestMeView(presetSubject: lesson.title)) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                        Text("Test me on \(lesson.title)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .foregroundStyle(Theme.primaryText)
                    .padding(12)
                    .glassPanel(cornerRadius: 10, borderColor: MindMapSection.school.accentColor.opacity(0.7))
                }

                itemsSection(title: "ASSIGNMENTS", items: pendingHomework + doneHomework, emptyText: "Nothing added yet.")
                itemsSection(title: "TESTS & QUIZZES", items: pendingTests + doneTests, emptyText: "Nothing added yet.")
                materialsSection

                if let notes = lesson.notes, !notes.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("NOTES")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Theme.dimText)
                        Text(notes).font(.caption).foregroundStyle(Theme.primaryText)
                    }
                }

                AskAIHelpBox(contextLabel: lesson.title)

                NotesSectionView(context: .lesson(lesson.id), accentColor: MindMapSection.school.accentColor)
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(lesson.title)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button { addingAssignment = true } label: { Label("Add Assignment", systemImage: "doc.text") }
                    Button { addingQuiz = true } label: { Label("Add Test/Quiz", systemImage: "questionmark.circle") }
                    Button { addingMaterial = true } label: { Label("Add Material", systemImage: "paperclip") }
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $addingAssignment) {
            AddEditAssignmentView(assignment: nil, presetLesson: lesson, presetIsQuiz: false)
        }
        .sheet(isPresented: $addingQuiz) {
            AddEditAssignmentView(assignment: nil, presetLesson: lesson, presetIsQuiz: true)
        }
        .sheet(isPresented: $addingMaterial) {
            AddEditLessonMaterialView(material: nil, presetLesson: lesson)
        }
        .sheet(item: $editingAssignment) { assignment in
            AddEditAssignmentView(assignment: assignment)
        }
        .sheet(item: $editingMaterial) { material in
            AddEditLessonMaterialView(material: material)
        }
    }

    // MARK: - Assignments & tests/quizzes

    private func itemsSection(title: String, items: [Assignment], emptyText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            if items.isEmpty {
                Text(emptyText)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        assignmentRow(item)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func assignmentRow(_ assignment: Assignment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        assignment.isDone.toggle()
                    }
                    NotificationManager.shared.sync(assignment: assignment)
                    if assignment.isDone { NotificationManager.shared.notifyTaskCompleted(title: assignment.title) }
                } label: {
                    Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(assignment.isDone ? MindMapSection.school.accentColor : Theme.dimText)
                }
                .buttonStyle(.plain)

                VStack(alignment: .leading, spacing: 1) {
                    Text(assignment.title)
                        .font(.subheadline)
                        .foregroundStyle(assignment.isDone ? Theme.dimText : Theme.primaryText)
                        .strikethrough(assignment.isDone)
                    if let due = assignment.dueDate {
                        Text(due.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.dimText)
                    }
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
                    helpUnderstand(assignment)
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

    private func helpUnderstand(_ assignment: Assignment) {
        explainingAssignment = assignment
        isExplaining = true
        explainError = nil
        let prompt = "Explain this assignment/test so I actually understand it, step by step: \"\(assignment.title)\" under the lesson \"\(lesson.title)\"." + (assignment.notes.map { " Extra context: \($0)" } ?? "")

        Task {
            do {
                let explanation = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: nil,
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

    // MARK: - Materials

    private var materialsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MATERIALS")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            if lesson.materials.isEmpty {
                Text("Nothing added yet — attach links, docs, slideshows, or downloads.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(lesson.materials.sorted { $0.createdAt < $1.createdAt }.enumerated()), id: \.element.id) { index, material in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        materialRow(material)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func materialRow(_ material: LessonMaterial) -> some View {
        HStack(spacing: 10) {
            Image(systemName: material.kind.icon)
                .foregroundStyle(MindMapSection.school.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(material.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                Text(material.kind.displayName + (material.fileName.map { " · \($0)" } ?? ""))
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            if let urlString = material.urlString, let url = URL(string: urlString) {
                Link(destination: url) {
                    Image(systemName: "arrow.up.right.square")
                        .foregroundStyle(Theme.dimText)
                }
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { editingMaterial = material }
    }
}

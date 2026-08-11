//
//  TopicDetailView.swift
//  Odysseus
//
//  Lessons within one topic. Each lesson is where assignments, tests/
//  quizzes, and materials actually get added, plus a direct line into
//  Test Me and AI help scoped to this topic.
//

import SwiftUI
import SwiftData

struct TopicDetailView: View {
    @Bindable var topic: Topic

    @Environment(\.modelContext) private var modelContext
    @State private var newLessonTitle = ""
    @State private var editingLesson: Lesson?

    private var lessons: [Lesson] { topic.lessons.sorted { $0.sortIndex < $1.sortIndex } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                NavigationLink(destination: TestMeView(presetSubject: topic.name)) {
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
                    Text("LESSONS")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.dimText)

                    HStack(spacing: 8) {
                        TextField("Add a lesson", text: $newLessonTitle)
                            .padding(10)
                            .glassPanel(cornerRadius: 8)
                            .onSubmit(addLesson)
                        Button(action: addLesson) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                                .foregroundStyle(newLessonTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dimText : MindMapSection.school.accentColor)
                        }
                        .buttonStyle(.plain)
                        .disabled(newLessonTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }

                    if lessons.isEmpty {
                        Text("Nothing added yet — add a lesson, then log its assignments, tests/quizzes, and materials inside it.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(lessons.enumerated()), id: \.element.id) { index, lesson in
                                if index > 0 {
                                    Divider().overlay(Theme.cardBorder)
                                }
                                lessonRow(lesson)
                            }
                        }
                        .glassPanel(cornerRadius: 10)
                    }
                }

                AskAIHelpBox(contextLabel: topic.name)

                NotesSectionView(context: .topic(topic.id), accentColor: MindMapSection.school.accentColor)
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(topic.name)
        .inlineNavigationTitle()
        .sheet(item: $editingLesson) { lesson in
            AddEditLessonView(lesson: lesson)
        }
    }

    private func lessonRow(_ lesson: Lesson) -> some View {
        NavigationLink(destination: LessonDetailView(lesson: lesson)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(lesson.title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.primaryText)
                    let pending = lesson.assignments.filter { !$0.isDone }.count
                    let materialCount = lesson.materials.count
                    Text(summary(pending: pending, materialCount: materialCount))
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                Button {
                    editingLesson = lesson
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.dimText)
                }
                .buttonStyle(.plain)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func summary(pending: Int, materialCount: Int) -> String {
        var parts: [String] = []
        parts.append(pending == 0 ? "All caught up" : "\(pending) pending")
        if materialCount > 0 { parts.append("\(materialCount) material\(materialCount == 1 ? "" : "s")") }
        return parts.joined(separator: " · ")
    }

    private func addLesson() {
        let trimmed = newLessonTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextIndex = (lessons.map(\.sortIndex).max() ?? -1) + 1
        modelContext.insert(Lesson(title: trimmed, sortIndex: nextIndex, topic: topic))
        newLessonTitle = ""
    }
}

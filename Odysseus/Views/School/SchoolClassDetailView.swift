//
//  SchoolClassDetailView.swift
//  Odysseus
//
//  Full-screen list of topics within one class. Topics are where assignments
//  actually live and what Test Me quizzes you on.
//

import SwiftUI
import SwiftData

struct SchoolClassDetailView: View {
    @Bindable var schoolClass: SchoolClass

    @Environment(\.modelContext) private var modelContext
    @Query private var allExams: [Exam]
    @State private var newTopicName = ""
    @State private var addingExam = false
    @State private var editingExam: Exam?

    private var topics: [Topic] { schoolClass.topics.sorted { $0.sortIndex < $1.sortIndex } }

    /// Exams logged for this class specifically — this is what makes logging
    /// a test on the Calendar/School exams screen also show up here.
    private var exams: [Exam] {
        let classID = schoolClass.id
        return allExams.filter { $0.schoolClass?.id == classID }.sorted { $0.examDate < $1.examDate }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if !exams.isEmpty {
                    examsSection
                }

                HStack(spacing: 8) {
                    TextField("Add a topic (e.g. Recursion, Photosynthesis)", text: $newTopicName)
                        .padding(10)
                        .glassPanel(cornerRadius: 8)
                        .onSubmit(addTopic)
                    Button(action: addTopic) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(newTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dimText : MindMapSection.school.accentColor)
                    }
                    .buttonStyle(.plain)
                    .disabled(newTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if topics.isEmpty {
                    Text("No topics yet. Add a unit or lesson above, then log its assignments and test yourself on it.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            topicRow(topic)
                        }
                    }
                    .glassPanel(cornerRadius: 10)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(schoolClass.name)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    addingExam = true
                } label: {
                    Label("Add test", systemImage: "graduationcap.badge.plus")
                }
            }
        }
        .sheet(isPresented: $addingExam) {
            AddEditExamView(exam: nil, presetClass: schoolClass)
        }
        .sheet(item: $editingExam) { exam in
            AddEditExamView(exam: exam)
        }
    }

    private var examsSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TESTS")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.dimText)
            VStack(spacing: 0) {
                ForEach(Array(exams.enumerated()), id: \.element.id) { index, exam in
                    if index > 0 {
                        Divider().overlay(Theme.cardBorder)
                    }
                    examRow(exam)
                }
            }
            .glassPanel(cornerRadius: 10)
        }
    }

    private func examRow(_ exam: Exam) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(MindMapSection.school.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(exam.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                    .strikethrough(exam.isPast && exam.hasScore)
                Text(exam.examDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            if exam.hasScore {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.terminalGreen)
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { editingExam = exam }
    }

    private func topicRow(_ topic: Topic) -> some View {
        NavigationLink(destination: TopicDetailView(topic: topic)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(topic.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.primaryText)
                    let pending = topic.assignments.filter { !$0.isDone }.count
                    Text(pending == 0 ? "All caught up" : "\(pending) pending")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func addTopic() {
        let trimmed = newTopicName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextIndex = (topics.map(\.sortIndex).max() ?? -1) + 1
        modelContext.insert(Topic(name: trimmed, sortIndex: nextIndex, schoolClass: schoolClass))
        NotificationManager.shared.notifyMaterialAdded(className: schoolClass.name, materialName: trimmed)
        newTopicName = ""
    }
}

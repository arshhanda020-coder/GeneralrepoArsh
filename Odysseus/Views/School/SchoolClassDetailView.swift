//
//  SchoolClassDetailView.swift
//  Odysseus
//
//  Full-screen list of topics within one class. Topics are where assignments
//  actually live and what Test Me quizzes you on. Summer Work sits in its
//  own section, unaffected by the Fall/Spring filter, since it's never part
//  of either semester and never counts toward the grade above.
//

import SwiftUI
import SwiftData

struct SchoolClassDetailView: View {
    @Bindable var schoolClass: SchoolClass

    @Environment(\.modelContext) private var modelContext
    @State private var newTopicName = ""
    @State private var newSummerWorkName = ""
    @State private var term: SchoolTerm = SchoolTermSettings.selected

    private var topics: [Topic] { schoolClass.topics.filter { !$0.isSummerWork }.sorted { $0.sortIndex < $1.sortIndex } }
    private var summerWork: [Topic] { schoolClass.topics.filter(\.isSummerWork).sorted { $0.sortIndex < $1.sortIndex } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                SemesterPicker(selection: $term)
                gradeHeader
                topicsSection
                summerWorkSection
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(schoolClass.name)
        .inlineNavigationTitle()
        .onChange(of: term) { _, newValue in SchoolTermSettings.selected = newValue }
    }

    private var gradeHeader: some View {
        let summary = schoolClass.gradeSummary(includeMock: false, term: term)
        return HStack {
            VStack(alignment: .leading, spacing: 1) {
                if let percent = summary.percent {
                    Text(summary.isManual ? "Manual grade" : "\(String(format: "%.0f", summary.pointsEarned))/\(String(format: "%.0f", summary.pointsPossible)) points")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                    Text(String(format: "%.1f%%", percent))
                        .font(.title2.weight(.heavy).monospacedDigit())
                        .foregroundStyle(MindMapSection.school.accentColor)
                } else {
                    Text("No graded work logged yet")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
            }
            Spacer()
        }
        .padding(12)
        .glassPanel(cornerRadius: 10)
    }

    // MARK: - Topics

    private var topicsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TOPICS")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

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
    }

    private func topicRow(_ topic: Topic) -> some View {
        // Scoped to the selected semester — Summer Work topics never land here, so they're untouched by this filter.
        let scoped = topic.assignments.filter { term.matches($0.dueDate ?? $0.createdAt) }
        return NavigationLink(destination: TopicDetailView(topic: topic)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(topic.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.primaryText)
                    let pending = scoped.filter { !$0.isDone }.count
                    Text(scoped.isEmpty ? "Nothing this term" : (pending == 0 ? "All caught up" : "\(pending) pending"))
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
        let nextIndex = (schoolClass.topics.map(\.sortIndex).max() ?? -1) + 1
        modelContext.insert(Topic(name: trimmed, sortIndex: nextIndex, schoolClass: schoolClass))
        newTopicName = ""
    }

    // MARK: - Summer Work

    private var summerWorkSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SUMMER WORK")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            Text("Never counts toward this class's grade, and always shown here regardless of the semester above.")
                .font(.caption2)
                .foregroundStyle(Theme.dimText)

            HStack(spacing: 8) {
                TextField("Add summer work (e.g. Summer reading)", text: $newSummerWorkName)
                    .padding(10)
                    .glassPanel(cornerRadius: 8)
                    .onSubmit(addSummerWork)
                Button(action: addSummerWork) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newSummerWorkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dimText : MindMapSection.school.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newSummerWorkName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if summerWork.isEmpty {
                Text("Nothing added yet.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(summerWork.enumerated()), id: \.element.id) { index, topic in
                        if index > 0 {
                            Divider().overlay(Theme.cardBorder)
                        }
                        summerWorkRow(topic)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func summerWorkRow(_ topic: Topic) -> some View {
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

    private func addSummerWork() {
        let trimmed = newSummerWorkName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let nextIndex = (schoolClass.topics.map(\.sortIndex).max() ?? -1) + 1
        modelContext.insert(Topic(name: trimmed, sortIndex: nextIndex, schoolClass: schoolClass, isSummerWork: true))
        newSummerWorkName = ""
    }
}

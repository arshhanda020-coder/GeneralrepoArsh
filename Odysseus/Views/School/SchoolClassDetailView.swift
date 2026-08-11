//
//  SchoolClassDetailView.swift
//  Odysseus
//
//  Classroom-style class page: a colored banner up top, then a Stream tab
//  (recent activity feed) and a Classwork tab (topic groups with assignment
//  cards) — topics are still where assignments actually live and what Test
//  Me quizzes you on.
//

import SwiftUI
import SwiftData

private enum ClassPageTab: String, CaseIterable, Identifiable {
    case stream = "Stream"
    case classwork = "Classwork"
    var id: String { rawValue }
}

struct SchoolClassDetailView: View {
    @Bindable var schoolClass: SchoolClass

    @Environment(\.modelContext) private var modelContext
    @Query private var allExams: [Exam]
    @State private var newTopicName = ""
    @State private var addingExam = false
    @State private var editingExam: Exam?
    @State private var pickingColor = false
    @State private var selectedTab: ClassPageTab = .stream

    private var topics: [Topic] { schoolClass.topics.sorted { $0.sortIndex < $1.sortIndex } }

    /// Exams logged for this class specifically — this is what makes logging
    /// a test on the Calendar/School exams screen also show up here.
    private var exams: [Exam] {
        let classID = schoolClass.id
        return allExams.filter { $0.schoolClass?.id == classID }.sorted { $0.examDate < $1.examDate }
    }

    /// Most-recently-added assignments across every topic, newest first —
    /// the Stream tab's "recent classwork" feed.
    private var recentAssignments: [(topic: Topic, assignment: Assignment)] {
        var pairs: [(topic: Topic, assignment: Assignment)] = []
        for topic in topics {
            for assignment in topic.assignments {
                pairs.append((topic: topic, assignment: assignment))
            }
        }
        return pairs.sorted { $0.assignment.createdAt > $1.assignment.createdAt }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                banner

                Picker("", selection: $selectedTab) {
                    ForEach(ClassPageTab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(12)

                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .stream: streamTab
                    case .classwork: classworkTab
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(schoolClass.name)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        pickingColor = true
                    } label: {
                        Label("Customize color", systemImage: "paintpalette")
                    }
                    Button {
                        addingExam = true
                    } label: {
                        Label("Add test", systemImage: "graduationcap.badge.plus")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $addingExam) {
            AddEditExamView(exam: nil, presetClass: schoolClass)
        }
        .sheet(item: $editingExam) { exam in
            AddEditExamView(exam: exam)
        }
        .sheet(isPresented: $pickingColor) {
            ClassColorPickerSheet(schoolClass: schoolClass)
        }
    }

    // MARK: - Banner

    private var banner: some View {
        let pendingCount = topics.flatMap(\.assignments).filter { !$0.isDone }.count
        return ZStack(alignment: .bottomLeading) {
            schoolClass.bannerColor.gradient

            Image(systemName: "graduationcap.fill")
                .font(.system(size: 64))
                .foregroundStyle(.white.opacity(0.14))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            if let grade = schoolClass.effectiveGradeLabel {
                VStack(spacing: 0) {
                    Text(grade)
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(.white)
                    if let percent = schoolClass.calculatedPercent {
                        Text("\(String(format: "%.1f", percent))%")
                            .font(.caption2.weight(.medium).monospacedDigit())
                            .foregroundStyle(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                .padding(16)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(schoolClass.name)
                    .font(.title2.weight(.bold))
                    .foregroundStyle(.white)
                Text("\(topics.count) \(topics.count == 1 ? "topic" : "topics") · \(pendingCount == 0 ? "all caught up" : "\(pendingCount) pending")")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.85))
            }
            .shadow(color: .black.opacity(0.25), radius: 3, y: 1)
            .padding(16)
        }
        .frame(height: 128)
    }

    // MARK: - Stream

    private var streamTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if !exams.isEmpty {
                streamSection(title: "UPCOMING TESTS") {
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

            streamSection(title: "RECENT CLASSWORK") {
                if recentAssignments.isEmpty {
                    Text("Nothing posted yet — add a topic in Classwork to get started.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(recentAssignments.prefix(6).enumerated()), id: \.element.assignment.id) { index, entry in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            streamAssignmentRow(entry.assignment, topic: entry.topic)
                        }
                    }
                    .glassPanel(cornerRadius: 10)
                }
            }
        }
    }

    private func streamSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            content()
        }
    }

    private func examRow(_ exam: Exam) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "graduationcap.fill")
                .foregroundStyle(schoolClass.bannerColor.base)
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

    private func streamAssignmentRow(_ assignment: Assignment, topic: Topic) -> some View {
        NavigationLink(destination: TopicDetailView(topic: topic)) {
            HStack(spacing: 10) {
                Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(assignment.isDone ? schoolClass.bannerColor.base : Theme.dimText)
                VStack(alignment: .leading, spacing: 1) {
                    Text(assignment.title)
                        .font(.subheadline)
                        .foregroundStyle(assignment.isDone ? Theme.dimText : Theme.primaryText)
                        .strikethrough(assignment.isDone)
                    Text(topic.name)
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                if let score = assignment.scoreLabel {
                    Text(score)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(schoolClass.bannerColor.base)
                }
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Classwork

    private var classworkTab: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                TextField("Add a topic (e.g. Recursion, Photosynthesis)", text: $newTopicName)
                    .padding(10)
                    .glassPanel(cornerRadius: 8)
                    .onSubmit(addTopic)
                Button(action: addTopic) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dimText : schoolClass.bannerColor.base)
                }
                .buttonStyle(.plain)
                .disabled(newTopicName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if topics.isEmpty {
                Text("No topics yet. Add a unit or lesson above, then log its assignments and test yourself on it.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                ForEach(topics) { topic in
                    topicGroup(topic)
                }
            }
        }
    }

    /// A Classroom "topic" group: a label header for the unit, its
    /// assignments as cards right underneath, and a way into the topic's
    /// full page for Test Me / notes / "help me understand".
    private func topicGroup(_ topic: Topic) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            NavigationLink(destination: TopicDetailView(topic: topic)) {
                HStack(spacing: 6) {
                    Rectangle()
                        .fill(schoolClass.bannerColor.base)
                        .frame(width: 3, height: 16)
                        .clipShape(Capsule())
                    Text(topic.name.uppercased())
                        .font(.system(.caption, design: .monospaced).weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if topic.assignments.isEmpty {
                Text("No assignments yet")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
                    .padding(.leading, 9)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topic.assignments.enumerated()), id: \.element.id) { index, assignment in
                        if index > 0 {
                            Divider().overlay(Theme.cardBorder)
                        }
                        assignmentCard(assignment, topic: topic)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func assignmentCard(_ assignment: Assignment, topic: Topic) -> some View {
        NavigationLink(destination: TopicDetailView(topic: topic)) {
            HStack(spacing: 10) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        assignment.isDone.toggle()
                    }
                    NotificationManager.shared.sync(assignment: assignment)
                    if assignment.isDone { NotificationManager.shared.notifyTaskCompleted(title: assignment.title) }
                } label: {
                    Image(systemName: assignment.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(assignment.isDone ? schoolClass.bannerColor.base : Theme.dimText)
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

                if let score = assignment.scoreLabel {
                    Text(score)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(schoolClass.bannerColor.base)
                }
                if assignment.understood == true {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(Theme.terminalGreen)
                }
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

//
//  MyTestsView.swift
//  Odysseus
//
//  Replaces the old flat per-category exam lists on the School page with
//  one hub split into the three things they actually mean differently:
//  March Exams (AI-personalized finals prep, per class), ACT, and AP Exams
//  — the latter two their own systems (session logging, AI study plans),
//  not shared with each other or with March Exams.
//

import SwiftUI
import SwiftData

private enum MyTestsTab: String, CaseIterable, Identifiable {
    case marchExams = "March Exams"
    case act = "ACT"
    case apExams = "AP Exams"
    var id: String { rawValue }

    var category: ExamCategory {
        switch self {
        case .marchExams: return .marchExams
        case .act: return .act
        case .apExams: return .apExams
        }
    }
}

struct MyTestsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SchoolClass.sortIndex) private var allClasses: [SchoolClass]
    @Query(sort: \Exam.examDate) private var allExams: [Exam]
    // Re-read every time the underlying data changes so the level bar stays live.
    @Query private var allSessions: [StudySession]
    @Query private var allAssignments: [Assignment]

    @State private var selectedTab: MyTestsTab = .marchExams
    @State private var addingExam: ExamCategory?
    @State private var editingExam: Exam?

    private var enrolledClasses: [SchoolClass] { allClasses.filter(\.isEnrolled) }

    var body: some View {
        VStack(spacing: 0) {
            levelHeader

            Picker("", selection: $selectedTab) {
                ForEach(MyTestsTab.allCases) { tab in
                    Text(tab.rawValue).tag(tab)
                }
            }
            .pickerStyle(.segmented)
            .padding(12)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch selectedTab {
                    case .marchExams: marchExamsTab
                    case .act: examListTab(.act, addTitle: "Add ACT test")
                    case .apExams: examListTab(.apExams, addTitle: "Add AP exam")
                    }
                }
                .padding(12)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("My Tests")
        .inlineNavigationTitle()
        .sheet(item: $addingExam) { category in
            AddEditExamView(exam: nil, presetCategory: category)
        }
        .sheet(item: $editingExam) { exam in
            AddEditExamView(exam: exam)
        }
    }

    // MARK: - Level

    /// A light gamification read on School activity — level/XP derived live
    /// from study sessions logged, topics reviewed, graded work, and exam
    /// scores, so it's always in sync with the real data (see StudyProgress).
    private var levelHeader: some View {
        let stats = StudyProgress.stats(modelContext: modelContext)
        return HStack(spacing: 10) {
            Text("LEVEL \(stats.level)")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(MindMapSection.school.accentColor)
            ProgressView(value: stats.progress)
                .tint(MindMapSection.school.accentColor)
            Text("\(stats.xpIntoLevel)/\(stats.xpPerLevel) XP")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.dimText)
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
    }

    // MARK: - March Exams

    private var marchExamsTab: some View {
        Group {
            if enrolledClasses.isEmpty {
                Text("Add your classes in Classes above — March Exam prep fills in per class once they're there.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(enrolledClasses.enumerated()), id: \.element.id) { index, schoolClass in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        marchExamRow(schoolClass)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func marchExamRow(_ schoolClass: SchoolClass) -> some View {
        NavigationLink(destination: MarchExamPrepView(schoolClass: schoolClass)) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(schoolClass.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.primaryText)
                    Text(pacingSummary(for: schoolClass))
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                if let grade = schoolClass.effectiveGradeLabel {
                    Text(grade)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(MindMapSection.school.accentColor)
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

    private func pacingSummary(for schoolClass: SchoolClass) -> String {
        if let exam = schoolClass.marchExam {
            return exam.isPast ? "Exam completed" : "Exam in \(exam.daysUntil)d"
        }
        return "No March Exam added yet"
    }

    // MARK: - ACT / AP Exams (shared list layout, separate systems underneath)

    private func examListTab(_ category: ExamCategory, addTitle: String) -> some View {
        let items = allExams.filter { $0.category == category }.sorted { $0.examDate < $1.examDate }
        return VStack(alignment: .leading, spacing: 10) {
            Button {
                addingExam = category
            } label: {
                Label(addTitle, systemImage: "plus.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .tint(MindMapSection.school.accentColor)

            if items.isEmpty {
                Text("Nothing added yet.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, exam in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        examRow(exam, category: category)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    @ViewBuilder
    private func examRow(_ exam: Exam, category: ExamCategory) -> some View {
        Group {
            if category == .act {
                NavigationLink(destination: ACTPrepView(exam: exam)) { examRowContent(exam) }
            } else {
                NavigationLink(destination: APExamPrepView(exam: exam)) { examRowContent(exam) }
            }
        }
        .buttonStyle(.plain)
    }

    private func examRowContent(_ exam: Exam) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(exam.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                Text(exam.examDate.formatted(.dateTime.month(.abbreviated).day().year()))
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            if exam.hasScore {
                Text(exam.actualScore ?? "")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.terminalGreen)
            } else if !exam.isPast {
                Text("\(exam.daysUntil)d")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(MindMapSection.school.accentColor)
            }
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
        .padding(10)
        .contentShape(Rectangle())
    }
}

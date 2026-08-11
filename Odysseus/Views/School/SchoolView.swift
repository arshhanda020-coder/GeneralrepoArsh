//
//  SchoolView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct SchoolView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SchoolClass.sortIndex) private var allClasses: [SchoolClass]
    @Query(sort: \Exam.examDate) private var exams: [Exam]

    @State private var showingManageClasses = false
    @State private var addingExamCategory: ExamCategory?
    @State private var editingExam: Exam?
    @State private var loggingExam: Exam?

    private var enrolledClasses: [SchoolClass] { allClasses.filter { $0.isEnrolled } }
    private var droppedClasses: [SchoolClass] { allClasses.filter { !$0.isEnrolled } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                classesSection
                examsSection

                navLinkRow(destination: GPACalculatorView(), icon: "chart.pie.fill", title: "GPA Calculator")
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("School")
        .sectionAssistantButton(.school)
        .sheet(item: $addingExamCategory) { category in
            AddEditExamView(exam: nil, presetCategory: category)
        }
        .sheet(item: $editingExam) { exam in
            AddEditExamView(exam: exam)
        }
        .sheet(item: $loggingExam) { exam in
            LogStudySessionSheet(exam: exam)
        }
        .sheet(isPresented: $showingManageClasses) {
            ManageClassesView()
        }
    }

    private func navLinkRow<Destination: View>(destination: Destination, icon: String, title: String) -> some View {
        NavigationLink(destination: destination) {
            HStack {
                Image(systemName: icon)
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Image(systemName: "chevron.right").font(.caption2)
            }
            .foregroundStyle(Theme.primaryText)
            .padding(12)
            .glassPanel(cornerRadius: 10, borderColor: MindMapSection.school.accentColor.opacity(0.7))
        }
    }

    // MARK: - Classes

    private let classGridColumns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]

    private var classesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("CLASSES")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button {
                    showingManageClasses = true
                } label: {
                    Text("Manage")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(MindMapSection.school.accentColor)
                }
                .buttonStyle(.plain)
            }

            if allClasses.isEmpty {
                EmptyStateView(
                    icon: MindMapSection.school.symbolName,
                    title: "No classes yet",
                    message: "Tap Manage to add your schedule.",
                    tint: MindMapSection.school.accentColor
                )
                .glassPanel(cornerRadius: 14)
            } else {
                LazyVGrid(columns: classGridColumns, spacing: 12) {
                    ForEach(enrolledClasses) { schoolClass in
                        NavigationLink(destination: SchoolClassDetailView(schoolClass: schoolClass)) {
                            ClassCardView(schoolClass: schoolClass)
                        }
                        .buttonStyle(.plain)
                    }
                }

                if !droppedClasses.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("NOT ENROLLED")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Theme.dimText)
                        LazyVGrid(columns: classGridColumns, spacing: 12) {
                            ForEach(droppedClasses) { schoolClass in
                                NavigationLink(destination: SchoolClassDetailView(schoolClass: schoolClass)) {
                                    ClassCardView(schoolClass: schoolClass, isDropped: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Exams

    private var examsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            ForEach(ExamCategory.allCases) { category in
                examCategorySection(category)
            }
        }
    }

    private func examCategorySection(_ category: ExamCategory) -> some View {
        let items = exams.filter { $0.category == category }.sorted { $0.examDate < $1.examDate }
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(category.displayName.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button {
                    addingExamCategory = category
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MindMapSection.school.accentColor)
                }
                .buttonStyle(.plain)
            }

            if items.isEmpty {
                Text("Nothing added yet.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                ForEach(items) { exam in
                    examCard(exam)
                }
            }
        }
    }

    private func examCard(_ exam: Exam) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.name)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text(exam.examDate.formatted(.dateTime.month(.wide).day().year()))
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                    if let target = exam.targetScore, !target.isEmpty {
                        Text("Target: \(target)")
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                }
                Spacer()
                if exam.hasScore {
                    VStack(spacing: 0) {
                        Text(exam.actualScore ?? "")
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(Theme.terminalGreen)
                        Text("SCORE")
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                    .frame(width: 60)
                } else if !exam.isPast {
                    VStack(spacing: 0) {
                        Text("\(exam.daysUntil)")
                            .font(.title3.weight(.heavy).monospacedDigit())
                            .foregroundStyle(MindMapSection.school.accentColor)
                        Text(exam.daysUntil == 1 ? "day" : "days")
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                    .frame(width: 52)
                } else {
                    Text("No score yet")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                        .frame(width: 70)
                }
                Button {
                    editingExam = exam
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .foregroundStyle(Theme.dimText)
                }
                .buttonStyle(.plain)
            }
            HStack {
                Text("\(exam.studySessions.count) study sessions logged")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
                Spacer()
                if exam.category == .act {
                    NavigationLink("Prep Plan") {
                        ACTPrepView(exam: exam)
                    }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.borderedProminent)
                    .tint(MindMapSection.school.accentColor)
                    .controlSize(.small)
                }
                Button("Log session") { loggingExam = exam }
                    .font(.caption.weight(.semibold))
                    .buttonStyle(.bordered)
                    .tint(MindMapSection.school.accentColor)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 10)
    }
}

#Preview {
    NavigationStack {
        SchoolView()
    }
    .modelContainer(for: [SchoolClass.self, Topic.self, Lesson.self, LessonMaterial.self, Assignment.self, Exam.self, StudySession.self, QuizSession.self, QuizQuestion.self], inMemory: true)
}

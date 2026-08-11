//
//  MarchExamPrepView.swift
//  Odysseus
//
//  My Tests > March Exams, for one class: the overall grade (coursework
//  blended with the exam once it's logged), the exam record itself, an AI
//  weakness analysis built from everything logged for the class, and each
//  topic's spaced-repetition pacing toward the exam date.
//

import SwiftUI
import SwiftData

struct MarchExamPrepView: View {
    @Bindable var schoolClass: SchoolClass

    @Environment(\.modelContext) private var modelContext
    @State private var addingExam = false
    @State private var editingExam: Exam?
    @State private var isAnalyzing = false
    @State private var analysisError: String?

    private var topics: [Topic] { schoolClass.topics.sorted { $0.sortIndex < $1.sortIndex } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                gradeSection
                examSection

                if let marchExam = schoolClass.marchExam {
                    StudyRoutineCard(exam: marchExam, focusPoints: topics.map(\.name))
                }

                NavigationLink(destination: TestMeView(presetSubject: schoolClass.name)) {
                    HStack {
                        Image(systemName: "questionmark.circle.fill")
                        Text("Test me on \(schoolClass.name)")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Image(systemName: "chevron.right").font(.caption2)
                    }
                    .foregroundStyle(Theme.primaryText)
                    .padding(12)
                    .glassPanel(cornerRadius: 10, borderColor: MindMapSection.school.accentColor.opacity(0.7))
                }

                weaknessSection
                pacingSection
                AskAIHelpBox(contextLabel: schoolClass.name)
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("March Exam Prep")
        .inlineNavigationTitle()
        .sheet(isPresented: $addingExam) {
            AddEditExamView(exam: nil, presetCategory: .marchExams, presetClass: schoolClass)
        }
        .sheet(item: $editingExam) { exam in
            AddEditExamView(exam: exam)
        }
    }

    // MARK: - Grade

    private var gradeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(schoolClass.name.uppercased()) — OVERALL GRADE")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(schoolClass.effectiveGradeLabel ?? "—")
                        .font(.title.weight(.heavy))
                        .foregroundStyle(Theme.primaryText)
                    if let percent = schoolClass.calculatedPercent {
                        Text("\(String(format: "%.1f", percent))%" + (schoolClass.marchExam?.calculatedPercent != nil ? " (coursework + exam, \(Int(schoolClass.examWeightPercent))% weight)" : " (coursework only)"))
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                }
                Spacer()
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
        }
    }

    // MARK: - Exam

    private var examSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("MARCH EXAM")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            if let exam = schoolClass.marchExam {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(exam.name)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.primaryText)
                        Text(exam.examDate.formatted(.dateTime.month(.wide).day().year()) + (exam.isPast ? "" : " · \(exam.daysUntil)d away"))
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                    Spacer()
                    if let percent = exam.calculatedPercent {
                        Text("\(String(format: "%.0f", percent))%")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(MindMapSection.school.accentColor)
                    }
                }
                .padding(10)
                .glassPanel(cornerRadius: 10)
                .contentShape(Rectangle())
                .onTapGesture { editingExam = exam }
            } else {
                Button {
                    addingExam = true
                } label: {
                    Label("Add March Exam for \(schoolClass.name)", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(MindMapSection.school.accentColor)
            }
        }
    }

    // MARK: - Weakness analysis

    private var weaknessSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("WEAK SPOTS & REVIEW PLAN")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                if let summary = schoolClass.lastReviewSummary {
                    Text(summary).font(.caption).foregroundStyle(Theme.primaryText)
                    if let at = schoolClass.lastReviewSummaryAt {
                        Text("Analyzed \(at.formatted(.dateTime.month(.abbreviated).day()))")
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                } else {
                    Text("Pulls in everything logged for this class — assignments, tests/quizzes, materials, notes — to find weak spots and suggest what to focus on.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
                Button {
                    analyzeWeaknesses()
                } label: {
                    Label(isAnalyzing ? "Analyzing…" : (schoolClass.lastReviewSummary == nil ? "Analyze" : "Re-analyze"), systemImage: "chart.bar.xaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.school.accentColor)
                .disabled(isAnalyzing)

                if let analysisError {
                    Text(analysisError).font(.caption).foregroundStyle(Theme.negative)
                }
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
        }
    }

    private func analyzeWeaknesses() {
        isAnalyzing = true
        analysisError = nil
        Task {
            do {
                let summary = try await MarchExamPrep.analyzeWeaknesses(for: schoolClass, modelContext: modelContext)
                schoolClass.lastReviewSummary = summary
                schoolClass.lastReviewSummaryAt = .now
            } catch {
                analysisError = error.localizedDescription
            }
            isAnalyzing = false
        }
    }

    // MARK: - Pacing

    private var pacingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("REVIEW PACING")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            if topics.isEmpty {
                Text("Add topics under this class to get a review schedule here.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(topics.enumerated()), id: \.element.id) { index, topic in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        pacingRow(topic)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func pacingRow(_ topic: Topic) -> some View {
        let examDate = schoolClass.marchExam?.examDate
        let nextReview = topic.nextReviewDate(examDate: examDate)
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(topic.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                Text(pacingLabel(nextReview: nextReview))
                    .font(.caption2)
                    .foregroundStyle(nextReview.map { $0 <= .now } == true ? MindMapSection.school.accentColor : Theme.dimText)
            }
            Spacer()
            Button("Mark reviewed") {
                withAnimation { topic.markReviewed() }
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .tint(MindMapSection.school.accentColor)
            .controlSize(.small)
        }
        .padding(10)
    }

    private func pacingLabel(nextReview: Date?) -> String {
        guard let nextReview else { return "Covered through the exam" }
        if nextReview <= .now { return "Review due now" }
        return "Next review: \(nextReview.formatted(.dateTime.month(.abbreviated).day()))"
    }
}

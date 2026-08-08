//
//  ACTPrepView.swift
//  Odysseus
//
//  Full ACT prep tracker for one ACT-category exam: an AI-generated,
//  regeneratable study plan; diagnostic/practice/official section scores;
//  study sessions tagged by section; and an AI strengths/weaknesses read
//  built from everything logged so far.
//

import SwiftUI
import SwiftData

struct ACTPrepView: View {
    @Bindable var exam: Exam

    @Environment(\.modelContext) private var modelContext
    @Query private var allPlans: [ACTPrepPlan]
    @Query private var allScores: [ACTSectionScore]
    @Query private var allSessions: [StudySession]

    @State private var isGeneratingPlan = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showingAddScore = false
    @State private var showingLogSession = false

    private var plan: ACTPrepPlan? {
        allPlans.filter { $0.exam?.id == exam.id }.sorted { $0.generatedAt > $1.generatedAt }.first
    }
    private var scores: [ACTSectionScore] {
        allScores.filter { $0.exam?.id == exam.id }.sorted { $0.takenAt > $1.takenAt }
    }
    private var sessions: [StudySession] {
        allSessions.filter { $0.exam?.id == exam.id }.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                planSection
                scoresSection
                strengthsSection
                sessionsSection
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("ACT Prep")
        .inlineNavigationTitle()
        .sheet(isPresented: $showingAddScore) {
            AddACTSectionScoreView(exam: exam)
        }
        .sheet(isPresented: $showingLogSession) {
            LogStudySessionSheet(exam: exam)
        }
    }

    // MARK: - Plan

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STUDY PLAN")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                if let plan {
                    Text(plan.planText)
                        .font(.caption)
                        .foregroundStyle(Theme.primaryText)
                    Text("Generated \(plan.generatedAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                } else {
                    Text("No plan yet. Generate one from your test date, target score, and any scores/sessions you've logged.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }

                Button {
                    generatePlan()
                } label: {
                    Label(isGeneratingPlan ? "Generating…" : (plan == nil ? "Generate Plan" : "Regenerate Plan"), systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.school.accentColor)
                .disabled(isGeneratingPlan)

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(Theme.negative)
                }
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
        }
    }

    // MARK: - Scores

    private var scoresSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("SCORES")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button {
                    showingAddScore = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MindMapSection.school.accentColor)
                }
                .buttonStyle(.plain)
            }

            if scores.isEmpty {
                Text("Log your diagnostic, practice, and official test scores here to track progress by section.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(scores.enumerated()), id: \.element.id) { index, score in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        scoreRow(score)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func scoreRow(_ score: ACTSectionScore) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(score.testType.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                if let composite = score.effectiveComposite {
                    Text("\(composite)")
                        .font(.title3.weight(.heavy).monospacedDigit())
                        .foregroundStyle(MindMapSection.school.accentColor)
                }
            }
            Text(score.takenAt.formatted(.dateTime.month(.abbreviated).day().year()))
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
            HStack(spacing: 12) {
                sectionStat("E", score.englishScore)
                sectionStat("M", score.mathScore)
                sectionStat("R", score.readingScore)
                sectionStat("S", score.scienceScore)
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture {
            modelContext.delete(score)
        }
    }

    private func sectionStat(_ label: String, _ value: Int?) -> some View {
        HStack(spacing: 3) {
            Text(label).font(.system(.caption2, design: .monospaced).weight(.bold)).foregroundStyle(Theme.dimText)
            Text(value.map(String.init) ?? "—").font(.caption.monospacedDigit()).foregroundStyle(Theme.primaryText)
        }
    }

    // MARK: - Strengths / weaknesses

    private var strengthsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STRENGTHS & WEAKNESSES")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                if let text = plan?.strengthsWeaknessesText {
                    Text(text).font(.caption).foregroundStyle(Theme.primaryText)
                } else {
                    Text("Log a couple of section scores, then analyze to see where to focus.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
                Button {
                    analyzeStrengths()
                } label: {
                    Label(isAnalyzing ? "Analyzing…" : "Analyze", systemImage: "chart.bar.xaxis")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(MindMapSection.school.accentColor)
                .disabled(isAnalyzing || scores.isEmpty)
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
        }
    }

    // MARK: - Sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("STUDY SESSIONS")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button {
                    showingLogSession = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MindMapSection.school.accentColor)
                }
                .buttonStyle(.plain)
            }

            if sessions.isEmpty {
                Text("Nothing logged yet.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.prefix(30).enumerated()), id: \.element.id) { index, session in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(session.subjectArea ?? "General")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.primaryText)
                                if let note = session.note, !note.isEmpty {
                                    Text(note).font(.caption2).foregroundStyle(Theme.dimText)
                                }
                            }
                            Spacer()
                            if let minutes = session.durationMinutes {
                                Text("\(minutes)m").font(.caption2.monospacedDigit()).foregroundStyle(Theme.dimText)
                            }
                            Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.dimText)
                        }
                        .padding(10)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    // MARK: - AI

    private func generatePlan() {
        isGeneratingPlan = true
        errorMessage = nil
        let daysUntil = exam.daysUntil
        let scoreHistory = scores.map { "\($0.testType.displayName) \($0.takenAt.formatted(.dateTime.month(.abbreviated).day())): composite \($0.effectiveComposite.map(String.init) ?? "n/a") (E:\($0.englishScore.map(String.init) ?? "-") M:\($0.mathScore.map(String.init) ?? "-") R:\($0.readingScore.map(String.init) ?? "-") S:\($0.scienceScore.map(String.init) ?? "-"))" }.joined(separator: "\n")
        let sessionHistory = sessions.prefix(20).map { "\($0.date.formatted(.dateTime.month(.abbreviated).day())): \($0.subjectArea ?? "General")\($0.note.map { " — \($0)" } ?? "")" }.joined(separator: "\n")

        let prompt = """
        Write a personalized ACT study plan.
        Test date: \(exam.examDate.formatted(.dateTime.month(.wide).day().year())) (\(daysUntil) days away)
        Target score: \(exam.targetScore ?? "not specified")
        Score history:
        \(scoreHistory.isEmpty ? "none logged yet" : scoreHistory)
        Recent study sessions:
        \(sessionHistory.isEmpty ? "none logged yet" : sessionHistory)

        Structure it as a realistic week-by-week plan given the time remaining, weighted toward whichever sections look weakest from the score history (if any). Be specific and actionable, not generic advice. Plain text, no markdown headers.
        """

        Task {
            do {
                let text = try await AISettings.currentService.draft(prompt: prompt)
                let newPlan = ACTPrepPlan(exam: exam, planText: text, strengthsWeaknessesText: plan?.strengthsWeaknessesText)
                modelContext.insert(newPlan)
            } catch {
                errorMessage = error.localizedDescription
            }
            isGeneratingPlan = false
        }
    }

    private func analyzeStrengths() {
        isAnalyzing = true
        errorMessage = nil
        let scoreHistory = scores.map { "\($0.testType.displayName) \($0.takenAt.formatted(.dateTime.month(.abbreviated).day())): E:\($0.englishScore.map(String.init) ?? "-") M:\($0.mathScore.map(String.init) ?? "-") R:\($0.readingScore.map(String.init) ?? "-") S:\($0.scienceScore.map(String.init) ?? "-")" }.joined(separator: "\n")
        let prompt = """
        Based on this ACT score history, identify clear strengths and weaknesses by section (English/Math/Reading/Science) and trend over time. 3-4 sentences, direct and specific, plain text.
        \(scoreHistory)
        """
        Task {
            do {
                let text = try await AISettings.currentService.draft(prompt: prompt)
                if let existingPlan = plan {
                    existingPlan.strengthsWeaknessesText = text
                } else {
                    let newPlan = ACTPrepPlan(exam: exam, planText: "No plan generated yet.", strengthsWeaknessesText: text)
                    modelContext.insert(newPlan)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }
}

private struct AddACTSectionScoreView: View {
    let exam: Exam

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var testType: ACTTestType = .practice
    @State private var takenAt = Date()
    @State private var english = ""
    @State private var math = ""
    @State private var reading = ""
    @State private var science = ""
    @State private var composite = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Test") {
                    Picker("Type", selection: $testType) {
                        ForEach(ACTTestType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    DatePicker("Date", selection: $takenAt, displayedComponents: .date)
                }
                Section("Section scores (1-36)") {
                    scoreField("English", $english)
                    scoreField("Math", $math)
                    scoreField("Reading", $reading)
                    scoreField("Science", $science)
                }
                Section("Composite") {
                    scoreField("Composite (optional — averaged if blank)", $composite)
                }
            }
            .navigationTitle("Log Score")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onSubmit { save() }
        }
    }

    private func scoreField(_ label: String, _ binding: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("—", text: binding)
                .platformKeyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
        }
    }

    private func save() {
        let score = ACTSectionScore(
            exam: exam,
            testType: testType,
            takenAt: takenAt,
            englishScore: Int(english),
            mathScore: Int(math),
            readingScore: Int(reading),
            scienceScore: Int(science),
            compositeScore: Int(composite)
        )
        modelContext.insert(score)
        dismiss()
    }
}

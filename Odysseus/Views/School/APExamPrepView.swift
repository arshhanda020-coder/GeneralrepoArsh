//
//  APExamPrepView.swift
//  Odysseus
//
//  AP's own prep tracker for one AP-category exam — its own system, not
//  ACT's: a single 1-5 score (via the exam's targetScore/actualScore)
//  rather than four sub-section scores, an AI-generated study plan, a
//  strengths/weaknesses read from session history, and session logging
//  (with optional screenshots).
//

import SwiftUI
import SwiftData

struct APExamPrepView: View {
    @Bindable var exam: Exam

    @Environment(\.modelContext) private var modelContext
    @Query private var allPlans: [APExamPrepPlan]
    @Query private var allSessions: [StudySession]

    @State private var isGeneratingPlan = false
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var showingLogSession = false
    @State private var showingScore = false

    private var plan: APExamPrepPlan? {
        allPlans.filter { $0.exam?.id == exam.id }.sorted { $0.generatedAt > $1.generatedAt }.first
    }
    private var sessions: [StudySession] {
        allSessions.filter { $0.exam?.id == exam.id }.sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                scoreSection
                planSection
                strengthsSection
                sessionsSection
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("AP Exam Prep")
        .inlineNavigationTitle()
        .sheet(isPresented: $showingLogSession) {
            LogStudySessionSheet(exam: exam)
        }
    }

    // MARK: - Score

    private var scoreSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SCORE (1–5)")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(exam.actualScore?.isEmpty == false ? exam.actualScore! : "Not scored yet")
                        .font(.title3.weight(.heavy))
                        .foregroundStyle(Theme.primaryText)
                    if let target = exam.targetScore, !target.isEmpty {
                        Text("Target: \(target)")
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                }
                Spacer()
                NavigationLink("Edit") {
                    AddEditExamView(exam: exam)
                }
                .font(.caption.weight(.semibold))
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
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
                    Text("No plan yet. Generate one from your exam date, target score, and any sessions you've logged.")
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
                    Text("Log a couple of study sessions with notes, then analyze to see where to focus.")
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
                .disabled(isAnalyzing || sessions.isEmpty)
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
                            if let screenshotData = session.screenshotData, let uiImage = PlatformImage(data: screenshotData) {
                                Image(platformImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 32, height: 32)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                if let note = session.note, !note.isEmpty {
                                    Text(note).font(.caption).foregroundStyle(Theme.primaryText)
                                } else {
                                    Text("Study session").font(.caption).foregroundStyle(Theme.dimText)
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
        let sessionHistory = sessions.prefix(20).map { "\($0.date.formatted(.dateTime.month(.abbreviated).day()))\($0.note.map { " — \($0)" } ?? "")" }.joined(separator: "\n")

        let prompt = """
        Write a personalized AP exam study plan.
        Exam: \(exam.name)
        Exam date: \(exam.examDate.formatted(.dateTime.month(.wide).day().year())) (\(daysUntil) days away)
        Target score: \(exam.targetScore ?? "not specified") (AP scores run 1-5)
        Current score, if taken before: \(exam.actualScore ?? "not specified")
        Recent study sessions:
        \(sessionHistory.isEmpty ? "none logged yet" : sessionHistory)

        Structure it as a realistic week-by-week plan given the time remaining. Be specific and actionable, not generic advice. Plain text, no markdown headers.
        """

        Task {
            do {
                let text = try await AISettings.currentService.draft(prompt: prompt)
                let newPlan = APExamPrepPlan(exam: exam, planText: text, strengthsWeaknessesText: plan?.strengthsWeaknessesText)
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
        let sessionHistory = sessions.map { "\($0.date.formatted(.dateTime.month(.abbreviated).day()))\($0.note.map { " — \($0)" } ?? "")" }.joined(separator: "\n")
        let prompt = """
        Based on this AP exam study session history, identify clear strengths and weaknesses and how consistently the student has been preparing. 3-4 sentences, direct and specific, plain text.
        \(sessionHistory)
        """
        Task {
            do {
                let text = try await AISettings.currentService.draft(prompt: prompt)
                if let existingPlan = plan {
                    existingPlan.strengthsWeaknessesText = text
                } else {
                    let newPlan = APExamPrepPlan(exam: exam, planText: "No plan generated yet.", strengthsWeaknessesText: text)
                    modelContext.insert(newPlan)
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isAnalyzing = false
        }
    }
}

//
//  TestMeView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct TestMeView: View {
    /// Set when navigated to from a specific Topic — locks the subject instead
    /// of making the user retype the topic name.
    var presetSubject: String?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuizSession.createdAt, order: .reverse) private var sessions: [QuizSession]

    @State private var subject = ""
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var activeSession: QuizSession?

    private var submittedSessions: [QuizSession] { sessions.filter { $0.isSubmitted } }

    private var masterySummary: [(subject: String, correct: Int, total: Int)] {
        let grouped = Dictionary(grouping: submittedSessions, by: { $0.subject })
        return grouped.map { subject, items in
            (subject, items.reduce(0) { $0 + $1.score }, items.reduce(0) { $0 + $1.totalQuestions })
        }.sorted { $0.subject < $1.subject }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SUBJECT")
                        .font(.caption2.weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.dimText)
                    if presetSubject != nil {
                        Text(subject)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
                    } else {
                        TextField("e.g. Stoichiometry, WWII causes, Derivatives", text: $subject)
                            .padding(10)
                            .background(Theme.card)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
                    }

                    Button {
                        generateQuiz()
                    } label: {
                        Label(isGenerating ? "Generating…" : "Test me", systemImage: "questionmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MindMapSection.school.accentColor)
                    .disabled(isGenerating || subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Color(hex: "C0605C"))
                }

                if !masterySummary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MASTERY")
                            .font(.caption2.weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Theme.dimText)
                        ForEach(masterySummary, id: \.subject) { entry in
                            masteryRow(entry)
                        }
                    }
                }

                if !submittedSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PAST TESTS")
                            .font(.caption2.weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Theme.dimText)
                        VStack(spacing: 0) {
                            ForEach(Array(submittedSessions.enumerated()), id: \.element.id) { index, session in
                                if index > 0 {
                                    Divider().overlay(Theme.cardBorder)
                                }
                                pastTestRow(session)
                            }
                        }
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
                    }
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Test Me")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if let presetSubject, subject.isEmpty {
                subject = presetSubject
            }
        }
        .fullScreenCover(item: $activeSession) { session in
            QuizSessionView(session: session)
        }
    }

    private func masteryRow(_ entry: (subject: String, correct: Int, total: Int)) -> some View {
        HStack {
            Text(entry.subject)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
            Text("\(entry.correct)/\(entry.total)")
                .foregroundStyle(MindMapSection.school.accentColor)
        }
        .font(.caption.monospacedDigit())
        .padding(10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private func pastTestRow(_ session: QuizSession) -> some View {
        Button {
            activeSession = session
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.subject)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)
                    Text(session.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                Text("\(session.score)/\(session.totalQuestions)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(MindMapSection.school.accentColor)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func generateQuiz() {
        isGenerating = true
        errorMessage = nil
        let topic = subject.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let drafts = try await AISettings.currentService.generateQuiz(subject: topic, count: 6)
                guard !drafts.isEmpty else {
                    errorMessage = "Couldn't generate questions — try again."
                    isGenerating = false
                    return
                }
                let session = QuizSession(subject: topic, totalQuestions: drafts.count)
                modelContext.insert(session)
                for (index, draft) in drafts.enumerated() {
                    modelContext.insert(QuizQuestion(
                        sortIndex: index,
                        text: draft.text,
                        type: draft.type,
                        choices: draft.choices,
                        correctAnswer: draft.correctAnswer,
                        session: session
                    ))
                }
                activeSession = session
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

#Preview {
    NavigationStack {
        TestMeView()
    }
    .modelContainer(for: [QuizSession.self, QuizQuestion.self], inMemory: true)
}

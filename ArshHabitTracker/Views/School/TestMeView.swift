//
//  TestMeView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct TestMeView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuizRecord.createdAt, order: .reverse) private var records: [QuizRecord]

    @State private var subject = ""
    @State private var currentQuestion: String?
    @State private var currentAnswer: String?
    @State private var showingAnswer = false
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var activeRecord: QuizRecord?

    private var masterySummary: [(subject: String, understood: Int, notUnderstood: Int)] {
        let grouped = Dictionary(grouping: records.filter { $0.understood != nil }, by: { $0.subject })
        return grouped.map { subject, items in
            (subject, items.filter { $0.understood == true }.count, items.filter { $0.understood == false }.count)
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
                    TextField("e.g. Stoichiometry, WWII causes, Derivatives", text: $subject)
                        .padding(10)
                        .background(Theme.card)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))

                    Button {
                        generateQuestion()
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
                        .foregroundStyle(Color(hex: "FF6B6B"))
                }

                if let currentQuestion {
                    questionCard(currentQuestion)
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
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Test Me")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func questionCard(_ question: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(question)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)

            if showingAnswer, let currentAnswer {
                Divider().overlay(Theme.cardBorder)
                Text(currentAnswer)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                Button("Show answer") {
                    showingAnswer = true
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.plain)
                .foregroundStyle(MindMapSection.school.accentColor)
            }

            HStack(spacing: 8) {
                Button {
                    mark(understood: true)
                } label: {
                    Label("I understand", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.terminalGreen)

                Button {
                    mark(understood: false)
                } label: {
                    Label("Don't understand", systemImage: "xmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(Color(hex: "FF6B6B"))
            }
            .font(.caption.weight(.semibold))
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private func masteryRow(_ entry: (subject: String, understood: Int, notUnderstood: Int)) -> some View {
        HStack {
            Text(entry.subject)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
            Spacer()
            Label("\(entry.understood)", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.terminalGreen)
            Label("\(entry.notUnderstood)", systemImage: "xmark.circle.fill")
                .foregroundStyle(Color(hex: "FF6B6B"))
        }
        .font(.caption.monospacedDigit())
        .padding(10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private func generateQuestion() {
        isGenerating = true
        errorMessage = nil
        showingAnswer = false
        currentQuestion = nil
        currentAnswer = nil
        let topic = subject.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let result = try await AISettings.currentService.generateQuizQuestion(subject: topic)
                currentQuestion = result.question
                currentAnswer = result.answer
                let record = QuizRecord(subject: topic, question: result.question, answer: result.answer)
                modelContext.insert(record)
                activeRecord = record
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }

    private func mark(understood: Bool) {
        activeRecord?.understood = understood
        currentQuestion = nil
        currentAnswer = nil
        activeRecord = nil
        showingAnswer = false
    }
}

#Preview {
    NavigationStack {
        TestMeView()
    }
    .modelContainer(for: [QuizRecord.self], inMemory: true)
}

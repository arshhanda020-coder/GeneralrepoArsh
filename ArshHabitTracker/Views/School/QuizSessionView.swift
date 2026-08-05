//
//  QuizSessionView.swift
//  ArshHabitTracker
//
//  Locked while answering (no dismiss, no back button) — once submitted it
//  becomes a review screen: score, right/wrong per question, and for
//  anything wrong, a prompt for the user's own improvement plan.
//

import SwiftUI
import SwiftData

struct QuizSessionView: View {
    @Bindable var session: QuizSession

    @Environment(\.dismiss) private var dismiss
    @State private var isSubmitting = false
    @State private var submitError: String?

    private var orderedQuestions: [QuizQuestion] { session.questions.sorted { $0.sortIndex < $1.sortIndex } }

    private var allAnswered: Bool {
        orderedQuestions.allSatisfy { !($0.userAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if session.isSubmitted {
                        scoreHeader
                    } else {
                        Text("Answer every question, then submit. You can't leave until you do.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    }

                    ForEach(Array(orderedQuestions.enumerated()), id: \.element.id) { index, question in
                        questionCard(question, index: index)
                    }

                    if !session.isSubmitted {
                        Button {
                            submit()
                        } label: {
                            Label(isSubmitting ? "Grading…" : "Submit", systemImage: "checkmark.seal.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Theme.accent)
                        .disabled(isSubmitting || !allAnswered)

                        if let submitError {
                            Text(submitError).font(.caption).foregroundStyle(Color(hex: "C0605C"))
                        }
                    }
                }
                .padding(12)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle(session.subject)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if session.isSubmitted {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(!session.isSubmitted)
    }

    private var scoreHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("\(session.score)/\(session.totalQuestions)")
                    .font(.title2.weight(.heavy).monospacedDigit())
                    .foregroundStyle(Theme.primaryText)
                Text("Score")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    @ViewBuilder
    private func questionCard(_ question: QuizQuestion, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Text("\(index + 1).")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.dimText)
                Text(question.text)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                if session.isSubmitted, let isCorrect = question.isCorrect {
                    Image(systemName: isCorrect ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(isCorrect ? Theme.terminalGreen : Color(hex: "C0605C"))
                }
            }

            if question.type == .multipleChoice {
                VStack(spacing: 6) {
                    ForEach(question.choices, id: \.self) { choice in
                        choiceRow(question, choice: choice)
                    }
                }
            } else if session.isSubmitted {
                Text("Your answer: \(question.userAnswer ?? "—")")
                    .font(.caption)
                    .foregroundStyle(Theme.primaryText)
            } else {
                TextField("Your answer", text: Binding(
                    get: { question.userAnswer ?? "" },
                    set: { question.userAnswer = $0 }
                ), axis: .vertical)
                    .lineLimit(2...5)
                    .padding(8)
                    .background(Theme.background)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
            }

            if session.isSubmitted {
                if question.type == .shortAnswer, let feedback = question.feedback, !feedback.isEmpty {
                    Text(feedback)
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
                if question.isCorrect == false {
                    Text("Correct answer: \(question.correctAnswer)")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                    improvementField(question)
                }
            }
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private func choiceRow(_ question: QuizQuestion, choice: String) -> some View {
        let isSelected = question.userAnswer == choice
        let isSubmitted = session.isSubmitted
        let isCorrectChoice = isSubmitted && choice == question.correctAnswer
        let isWrongSelected = isSubmitted && isSelected && !isCorrectChoice

        return Button {
            guard !isSubmitted else { return }
            question.userAnswer = choice
        } label: {
            HStack {
                Image(systemName: isSelected ? "largecircle.fill.circle" : "circle")
                Text(choice)
                    .font(.caption)
                Spacer()
                if isCorrectChoice {
                    Image(systemName: "checkmark")
                        .foregroundStyle(Theme.terminalGreen)
                }
            }
            .foregroundStyle(isWrongSelected ? Color(hex: "C0605C") : (isCorrectChoice ? Theme.terminalGreen : .white))
        }
        .buttonStyle(.plain)
        .disabled(isSubmitted)
    }

    private func improvementField(_ question: QuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("How will you prepare or make this better?")
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.dimText)
            TextField("Your plan", text: Binding(
                get: { question.improvementPlan ?? "" },
                set: { question.improvementPlan = $0 }
            ), axis: .vertical)
                .lineLimit(2...4)
                .padding(8)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private func submit() {
        isSubmitting = true
        submitError = nil
        Task {
            var correctCount = 0
            for question in orderedQuestions {
                let userAnswer = (question.userAnswer ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                switch question.type {
                case .multipleChoice:
                    let isCorrect = userAnswer.caseInsensitiveCompare(question.correctAnswer) == .orderedSame
                    question.isCorrect = isCorrect
                    if isCorrect { correctCount += 1 }
                case .shortAnswer:
                    do {
                        let grade = try await AISettings.currentService.gradeShortAnswer(
                            question: question.text,
                            correctAnswer: question.correctAnswer,
                            userAnswer: userAnswer
                        )
                        question.isCorrect = grade.isCorrect
                        question.feedback = grade.feedback
                        if grade.isCorrect { correctCount += 1 }
                    } catch {
                        question.isCorrect = false
                        question.feedback = "Couldn't grade automatically: \(error.localizedDescription)"
                    }
                }
            }
            session.score = correctCount
            session.isSubmitted = true
            isSubmitting = false
        }
    }
}

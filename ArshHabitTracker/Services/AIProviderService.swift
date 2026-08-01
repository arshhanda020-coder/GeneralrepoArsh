//
//  AIProviderService.swift
//  ArshHabitTracker
//
//  Common surface both AnthropicService and OpenAIService implement, so every
//  call site (Copilot, Jarvis, School, Food, Emails) can go through
//  AISettings.currentService without caring which provider is active.
//

import Foundation

struct QuizQuestionDraft: Sendable {
    let text: String
    let type: QuizQuestionType
    /// Empty for short-answer questions.
    let choices: [String]
    let correctAnswer: String
}

struct ShortAnswerGrade: Sendable {
    let isCorrect: Bool
    let feedback: String
}

protocol AIProviderService: Sendable {
    /// Full chat turn with tool use — used by Copilot/Jarvis.
    func send(
        history: [ChatMessage],
        toolExecutor: @escaping (String, [String: Any]) async -> String
    ) async throws -> String

    /// One-shot vision-capable call — homework help, macro estimation.
    func askAboutImage(prompt: String, imageData: Data?, systemPrompt: String) async throws -> String

    /// One-shot text draft — email composition.
    func draft(prompt: String) async throws -> String

    /// One-shot proactive suggestion given a status blob.
    func suggestion(for statusContext: String) async throws -> String

    /// A mixed set of multiple-choice and short-answer questions for the Test Me feature.
    func generateQuiz(subject: String, count: Int) async throws -> [QuizQuestionDraft]

    /// Grades a free-typed short answer against the reference answer.
    func gradeShortAnswer(question: String, correctAnswer: String, userAnswer: String) async throws -> ShortAnswerGrade
}

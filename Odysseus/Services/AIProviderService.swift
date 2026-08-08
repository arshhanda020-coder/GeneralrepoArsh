//
//  AIProviderService.swift
//  Odysseus
//
//  Common surface both AnthropicService and OpenAIService implement, so every
//  call site (Copilot, Odysseus, School, Food, Emails) can go through
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
    /// Full chat turn with tool use — used by Copilot/Odysseus. Streams via
    /// onTextDelta as tokens arrive (called on the response's final text
    /// turn only, not during tool-use turns) so the UI/voice can start
    /// responding before the whole reply is generated.
    func send(
        history: [ChatMessage],
        onTextDelta: ((String) -> Void)?,
        toolExecutor: @escaping (String, [String: Any]) async -> String
    ) async throws -> String

    /// Multi-turn chat scoped to a single app section (School, Health, Projects, …)
    /// — used by each section's own AI assistant. Unlike `send`, the system
    /// prompt is supplied by the caller (built fresh per section with a live
    /// snapshot of that section's data) instead of the fixed Copilot persona,
    /// and there's no tool use — a section assistant answers and advises, it
    /// doesn't take actions (Copilot remains the one place for that).
    func sendSectionChat(
        history: [ChatMessage],
        systemPrompt: String,
        onTextDelta: ((String) -> Void)?
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

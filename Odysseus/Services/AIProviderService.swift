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
    /// Full chat turn with tool use — used by Copilot/Odysseus, and by any
    /// other scoped assistant (e.g. the per-topic Study Assistant) that
    /// needs its own system prompt/tool set instead of Copilot's global one.
    /// Streams via onTextDelta as tokens arrive (called on the response's
    /// final text turn only, not during tool-use turns) so the UI/voice can
    /// start responding before the whole reply is generated.
    func send(
        history: [ChatMessage],
        onTextDelta: ((String) -> Void)?,
        systemPrompt: String?,
        tools: [[String: Any]]?,
        toolExecutor: @escaping (String, [String: Any]) async -> String
    ) async throws -> String

    /// One-shot vision-capable call — homework help, macro estimation.
    func askAboutImage(prompt: String, imageData: Data?, systemPrompt: String) async throws -> String

    /// One-shot text draft — email composition.
    func draft(prompt: String) async throws -> String

    /// One-shot proactive suggestion given a status blob.
    func suggestion(for statusContext: String) async throws -> String

    /// A mixed set of multiple-choice and short-answer questions for the Test Me feature.
    /// `material` (assignments/notes logged for the topic) and `difficulty` are both
    /// optional — nil for the plain "type a subject and go" flow.
    func generateQuiz(subject: String, count: Int, material: String?, difficulty: String?) async throws -> [QuizQuestionDraft]

    /// Grades a free-typed short answer against the reference answer.
    func gradeShortAnswer(question: String, correctAnswer: String, userAnswer: String) async throws -> ShortAnswerGrade
}

extension AIProviderService {
    /// Convenience overload for the common case (Copilot/Odysseus, one-shot
    /// research/agent calls): use the provider's own built-in system prompt
    /// and full tool set rather than a caller-supplied scoped one.
    func send(
        history: [ChatMessage],
        onTextDelta: ((String) -> Void)? = nil,
        toolExecutor: @escaping (String, [String: Any]) async -> String
    ) async throws -> String {
        try await send(history: history, onTextDelta: onTextDelta, systemPrompt: nil, tools: nil, toolExecutor: toolExecutor)
    }

    /// Convenience overload for the plain "type a subject and go" Test Me
    /// flow, with no topic material or difficulty steer to fold in.
    func generateQuiz(subject: String, count: Int) async throws -> [QuizQuestionDraft] {
        try await generateQuiz(subject: subject, count: count, material: nil, difficulty: nil)
    }
}

//
//  AIProviderService.swift
//  ArshHabitTracker
//
//  Common surface both AnthropicService and OpenAIService implement, so every
//  call site (Copilot, Jarvis, School, Food, Emails) can go through
//  AISettings.currentService without caring which provider is active.
//

import Foundation

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

    /// One question + answer for the Test Me quiz feature.
    func generateQuizQuestion(subject: String) async throws -> (question: String, answer: String)
}

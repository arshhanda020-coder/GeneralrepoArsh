//
//  AgentRunner.swift
//  Odysseus
//
//  Runs a subagent's instructions through the active AI provider and returns
//  the output — reuses the same chat pipeline as ResearchService (so it gets
//  Claude's web_search tool when available) rather than a bare one-shot call.
//

import Foundation

enum AgentRunner {
    static func run(instructions: String) async throws -> String {
        let syntheticHistory = [ChatMessage(role: "user", content: instructions)]
        return try await AISettings.currentService.send(history: syntheticHistory, onTextDelta: nil) { _, _ in
            "Tools aren't available during an agent run — just answer directly using web search and your own knowledge."
        }
    }
}

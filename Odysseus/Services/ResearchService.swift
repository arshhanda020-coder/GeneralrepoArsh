//
//  ResearchService.swift
//  Odysseus
//
//  Quality, structured research write-ups — reuses the same chat pipeline
//  Copilot uses (so Claude gets its web_search tool for real, current
//  grounding; ChatGPT has no browsing tool wired in, so its research is
//  knowledge-only) rather than a bare one-shot prompt.
//

import Foundation

enum ResearchService {
    static func research(topic: String, category: ResearchCategory) async throws -> String {
        let purpose: String
        switch category {
        case .school: purpose = "a school assignment or project — cite real sources where possible and keep it accurate enough to actually use for schoolwork"
        case .project: purpose = "a personal/coding project — practical, actionable findings"
        case .other: purpose = "general understanding"
        }

        let prompt = """
        Do quality, in-depth research on this topic and write a well-organized, substantive write-up — real depth \
        with specifics, not a shallow summary. Use web search if you have it, to ground this in current, real \
        information rather than guessing. Structure it with clear section headings where it helps. This is for \(purpose).

        Topic: \(topic)
        """

        let syntheticHistory = [ChatMessage(role: "user", content: prompt)]
        return try await AISettings.currentService.send(history: syntheticHistory, onTextDelta: nil) { _, _ in
            "Tools aren't available during research — just answer directly using web search and your own knowledge."
        }
    }
}

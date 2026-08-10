//
//  AgentDefinition.swift
//  Odysseus
//
//  A named, reusable AI subagent — a fixed set of instructions you can run
//  on demand (e.g. "Weekly Research Digest", "Portfolio Check-in"). Each run
//  is logged so you can see what it produced over time.
//

import Foundation
import SwiftData

@Model
final class AgentDefinition {
    var id: String
    var name: String
    var instructions: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \AgentRun.agent)
    var runs: [AgentRun] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        instructions: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.createdAt = createdAt
    }
}

/// A run's output, whether it came from the original chat-completion
/// AgentRunner (agent-defined runs) or from the Claude Code/Codex bridge
/// (project-scoped runs) — the bridge fields below are nil/default for the
/// former.
@Model
final class AgentRun {
    var id: String
    var output: String
    var createdAt: Date
    var agent: AgentDefinition?

    /// Set only for bridge runs: which CLI ran ("claudeCode"/"codex", see
    /// DevAgentKind.agentKey), the prompt that was sent, and how it went.
    var bridgeAgentKind: String?
    var prompt: String?
    var ok: Bool
    var errorMessage: String?
    var sessionId: String?
    var costUSD: Double?
    var fullAuto: Bool
    var project: Project?

    init(
        id: String = UUID().uuidString,
        output: String,
        createdAt: Date = .now,
        agent: AgentDefinition? = nil,
        bridgeAgentKind: String? = nil,
        prompt: String? = nil,
        ok: Bool = true,
        errorMessage: String? = nil,
        sessionId: String? = nil,
        costUSD: Double? = nil,
        fullAuto: Bool = false,
        project: Project? = nil
    ) {
        self.id = id
        self.output = output
        self.createdAt = createdAt
        self.agent = agent
        self.bridgeAgentKind = bridgeAgentKind
        self.prompt = prompt
        self.ok = ok
        self.errorMessage = errorMessage
        self.sessionId = sessionId
        self.costUSD = costUSD
        self.fullAuto = fullAuto
        self.project = project
    }
}

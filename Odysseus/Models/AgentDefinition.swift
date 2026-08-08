//
//  AgentDefinition.swift
//  Odysseus
//
//  A named, reusable agentic workflow — a fixed set of instructions you can
//  run on demand (e.g. "Weekly Research Digest", "Portfolio Check-in"). Each
//  run is logged so you can see what it produced over time. A workflow can
//  run as a plain chat completion, or against the real Claude Code / Codex
//  CLI via the bridge (see DevAgentBridgeClient) when it needs actual tool
//  use against a working directory rather than a one-shot answer.
//

import Foundation
import SwiftData

/// How a workflow's instructions get executed when you tap "Run Now".
enum AgentRunKind: String, Codable, CaseIterable, Identifiable {
    case chat
    case claudeCode
    case codex

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .chat: return "Chat"
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    /// The bridge's `DevAgentKind` counterpart — nil for `.chat`, which
    /// doesn't go through the bridge at all.
    var bridgeKind: DevAgentKind? {
        switch self {
        case .chat: return nil
        case .claudeCode: return .claudeCode
        case .codex: return .codex
        }
    }
}

@Model
final class AgentDefinition {
    var id: String
    var name: String
    var instructions: String
    var createdAt: Date

    /// Stored as the enum's rawValue for SwiftData compatibility; existing
    /// rows predate this field and lightweight-migrate to "chat".
    var runKindRaw: String = AgentRunKind.chat.rawValue
    /// Working directory to run against when `runKind` targets the bridge —
    /// unused for `.chat`.
    var workingDirectory: String?

    @Relationship(deleteRule: .cascade, inverse: \AgentRun.agent)
    var runs: [AgentRun] = []

    var runKind: AgentRunKind {
        get { AgentRunKind(rawValue: runKindRaw) ?? .chat }
        set { runKindRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        name: String,
        instructions: String,
        runKind: AgentRunKind = .chat,
        workingDirectory: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.instructions = instructions
        self.runKindRaw = runKind.rawValue
        self.workingDirectory = workingDirectory
        self.createdAt = createdAt
    }
}

@Model
final class AgentRun {
    var id: String
    var output: String
    var createdAt: Date
    var agent: AgentDefinition?

    init(
        id: String = UUID().uuidString,
        output: String,
        createdAt: Date = .now,
        agent: AgentDefinition? = nil
    ) {
        self.id = id
        self.output = output
        self.createdAt = createdAt
        self.agent = agent
    }
}

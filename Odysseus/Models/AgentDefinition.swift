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
    var id: String = UUID().uuidString
    var name: String = ""
    var instructions: String = ""
    var createdAt: Date = .now

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

@Model
final class AgentRun {
    var id: String = UUID().uuidString
    var output: String = ""
    var createdAt: Date = .now
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

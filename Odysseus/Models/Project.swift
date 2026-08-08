//
//  Project.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class Project {
    var id: String
    var name: String
    var emoji: String
    var colorHex: String
    var projectDescription: String
    var statusRaw: String
    var createdAt: Date
    /// A longer-form plan (written by the user or AI-generated) that tasks
    /// with due dates get broken out from.
    var planText: String?
    /// Absolute path (on the Mac running bridge/server.js) to this project's
    /// real repo, if any — what a bridge run's `cwd` is scoped to.
    var repoPath: String?

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask] = []

    /// Claude Code / Codex runs made against `repoPath` through the bridge,
    /// logged here so the project keeps a real history instead of the
    /// one-shot request/response DevAgentBridgeView shows.
    @Relationship(deleteRule: .cascade, inverse: \AgentRun.project)
    var agentRuns: [AgentRun] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        emoji: String,
        colorHex: String,
        projectDescription: String = "",
        status: ProjectStatus = .building,
        createdAt: Date = .now,
        planText: String? = nil,
        repoPath: String? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.projectDescription = projectDescription
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.planText = planText
        self.repoPath = repoPath
    }

    var status: ProjectStatus {
        get { ProjectStatus(rawValue: statusRaw) ?? .building }
        set { statusRaw = newValue.rawValue }
    }

    var progress: Double {
        guard !tasks.isEmpty else { return 0 }
        return Double(tasks.filter { $0.isDone }.count) / Double(tasks.count)
    }
}

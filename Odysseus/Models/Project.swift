//
//  Project.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class Project {
    var id: String = UUID().uuidString
    var name: String = ""
    var emoji: String = ""
    var colorHex: String = ""
    var projectDescription: String = ""
    var statusRaw: String = ProjectStatus.building.rawValue
    var createdAt: Date = .now
    /// A longer-form plan (written by the user or AI-generated) that tasks
    /// with due dates get broken out from.
    var planText: String?
    /// When the whole project (not just an individual task) is meant to be
    /// done — optional, separate from any task due dates. Set, this is what
    /// makes the project itself show up on the Calendar.
    var targetDate: Date?
    /// GitHub repo linked to this project (e.g. "https://github.com/owner/repo").
    var repoURLString: String?
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
        targetDate: Date? = nil,
        repoURLString: String? = nil,
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
        self.targetDate = targetDate
        self.repoURLString = repoURLString
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

    var repoURL: URL? {
        guard let repoURLString, !repoURLString.isEmpty else { return nil }
        return URL(string: repoURLString)
    }
}

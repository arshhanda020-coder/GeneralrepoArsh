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
    /// GitHub repo linked to this project (e.g. "https://github.com/owner/repo").
    var repoURLString: String?

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        emoji: String,
        colorHex: String,
        projectDescription: String = "",
        status: ProjectStatus = .building,
        createdAt: Date = .now,
        planText: String? = nil,
        repoURLString: String? = nil
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.projectDescription = projectDescription
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
        self.planText = planText
        self.repoURLString = repoURLString
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

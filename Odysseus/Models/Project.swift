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
    /// When the whole project (not just an individual task) is meant to be
    /// done — optional, separate from any task due dates. Set, this is what
    /// makes the project itself show up on the Calendar.
    var targetDate: Date?

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
        targetDate: Date? = nil
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

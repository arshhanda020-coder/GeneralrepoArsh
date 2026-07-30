//
//  Project.swift
//  ArshHabitTracker
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

    @Relationship(deleteRule: .cascade, inverse: \ProjectTask.project)
    var tasks: [ProjectTask] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        emoji: String,
        colorHex: String,
        projectDescription: String = "",
        status: ProjectStatus = .building,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.projectDescription = projectDescription
        self.statusRaw = status.rawValue
        self.createdAt = createdAt
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

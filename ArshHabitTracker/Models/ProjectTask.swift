//
//  ProjectTask.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class ProjectTask {
    var id: String
    var title: String
    var isDone: Bool
    var createdAt: Date
    var sortIndex: Int
    var dueDate: Date?
    var remindersOn: Bool
    var project: Project?

    init(
        id: String = UUID().uuidString,
        title: String,
        isDone: Bool = false,
        createdAt: Date = .now,
        sortIndex: Int = 0,
        dueDate: Date? = nil,
        remindersOn: Bool = false,
        project: Project? = nil
    ) {
        self.id = id
        self.title = title
        self.isDone = isDone
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.dueDate = dueDate
        self.remindersOn = remindersOn
        self.project = project
    }
}

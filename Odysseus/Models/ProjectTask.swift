//
//  ProjectTask.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class ProjectTask {
    var id: String = UUID().uuidString
    var title: String = ""
    var isDone: Bool = false
    var createdAt: Date = .now
    var sortIndex: Int = 0
    var dueDate: Date?
    var remindersOn: Bool = false
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

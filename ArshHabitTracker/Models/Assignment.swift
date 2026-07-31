//
//  Assignment.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class Assignment {
    var id: String
    var title: String
    var dueDate: Date?
    var isDone: Bool
    var notes: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        dueDate: Date? = nil,
        isDone: Bool = false,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.notes = notes
        self.createdAt = createdAt
    }
}

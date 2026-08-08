//
//  Assignment.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class Assignment {
    var id: String = UUID().uuidString
    var title: String = ""
    var dueDate: Date?
    var isDone: Bool = false
    var notes: String?
    var createdAt: Date = .now
    var topic: Topic?
    /// nil = not marked yet, true = "I understand", false = "Help me understand" was used.
    var understood: Bool?
    /// The AI's explanation from the last "Help me understand" tap.
    var helpExplanation: String?
    var remindersOn: Bool = false

    init(
        id: String = UUID().uuidString,
        title: String,
        dueDate: Date? = nil,
        isDone: Bool = false,
        notes: String? = nil,
        createdAt: Date = .now,
        topic: Topic? = nil,
        understood: Bool? = nil,
        helpExplanation: String? = nil,
        remindersOn: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.notes = notes
        self.createdAt = createdAt
        self.topic = topic
        self.understood = understood
        self.helpExplanation = helpExplanation
        self.remindersOn = remindersOn
    }
}

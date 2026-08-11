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
    var createdAt: Date = Date.now
    var lesson: Lesson?
    /// Distinguishes a test/quiz from regular homework within a lesson —
    /// same model, just a different badge and a different "Add" entry point.
    var isQuiz: Bool = false
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
        lesson: Lesson? = nil,
        isQuiz: Bool = false,
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
        self.lesson = lesson
        self.isQuiz = isQuiz
        self.understood = understood
        self.helpExplanation = helpExplanation
        self.remindersOn = remindersOn
    }
}

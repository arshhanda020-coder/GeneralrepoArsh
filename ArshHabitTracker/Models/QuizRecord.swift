//
//  QuizRecord.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class QuizRecord {
    var id: String
    var subject: String
    var question: String
    var answer: String
    /// true = "I understand", false = "I don't understand", nil = not yet marked.
    var understood: Bool?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        subject: String,
        question: String,
        answer: String,
        understood: Bool? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.subject = subject
        self.question = question
        self.answer = answer
        self.understood = understood
        self.createdAt = createdAt
    }
}

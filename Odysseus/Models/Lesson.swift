//
//  Lesson.swift
//  Odysseus
//
//  Sits between a Topic and the actual work — a Topic ("Recursion") is
//  broken into lessons, and each lesson is where assignments, tests/quizzes,
//  and materials (links, docs, slideshows, downloads) actually get added,
//  Google Classroom–style.
//

import Foundation
import SwiftData

@Model
final class Lesson {
    var id: String = UUID().uuidString
    var title: String = ""
    var notes: String?
    var createdAt: Date = Date.now
    var sortIndex: Int = 0
    var topic: Topic?

    @Relationship(deleteRule: .cascade, inverse: \Assignment.lesson)
    var assignments: [Assignment] = []

    @Relationship(deleteRule: .cascade, inverse: \LessonMaterial.lesson)
    var materials: [LessonMaterial] = []

    var tests: [Assignment] { assignments.filter(\.isQuiz) }
    var homework: [Assignment] { assignments.filter { !$0.isQuiz } }

    init(
        id: String = UUID().uuidString,
        title: String,
        notes: String? = nil,
        createdAt: Date = .now,
        sortIndex: Int = 0,
        topic: Topic? = nil
    ) {
        self.id = id
        self.title = title
        self.notes = notes
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.topic = topic
    }
}

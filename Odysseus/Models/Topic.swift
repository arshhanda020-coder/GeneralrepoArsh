//
//  Topic.swift
//  Odysseus
//
//  A unit within a class (e.g. "Recursion" under AP Computer Science), and
//  the thing you self-quiz on via Test Me. Broken down into lessons, which
//  is where assignments, tests/quizzes, and materials actually live.
//

import Foundation
import SwiftData

@Model
final class Topic {
    var id: String = UUID().uuidString
    var name: String = ""
    var createdAt: Date = Date.now
    var sortIndex: Int = 0
    var schoolClass: SchoolClass?

    @Relationship(deleteRule: .cascade, inverse: \Lesson.topic)
    var lessons: [Lesson] = []

    /// Convenience for anything that still wants a flat view of every
    /// assignment/quiz across this topic's lessons (pending counts, search).
    var assignments: [Assignment] { lessons.flatMap(\.assignments) }

    init(
        id: String = UUID().uuidString,
        name: String,
        createdAt: Date = .now,
        sortIndex: Int = 0,
        schoolClass: SchoolClass? = nil
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.schoolClass = schoolClass
    }
}

//
//  Topic.swift
//  Odysseus
//
//  A unit/lesson within a class (e.g. "Recursion" under AP Computer Science).
//  Assignments live under a topic, and a topic is the thing you self-quiz on
//  via Test Me.
//

import Foundation
import SwiftData

@Model
final class Topic {
    var id: String
    var name: String
    var createdAt: Date
    var sortIndex: Int
    var schoolClass: SchoolClass?

    @Relationship(deleteRule: .cascade, inverse: \Assignment.topic)
    var assignments: [Assignment] = []

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

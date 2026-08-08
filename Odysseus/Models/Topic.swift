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
    /// Summer work — same shape as a regular topic (assignments, notes,
    /// material) but never counted in a class's graded percentage/GPA, and
    /// always shown in its own section regardless of the Fall/Spring filter
    /// since it isn't part of either semester.
    var isSummerWork: Bool

    @Relationship(deleteRule: .cascade, inverse: \Assignment.topic)
    var assignments: [Assignment] = []

    /// Source material — imported PDFs/slideshows/files, or typed/pasted
    /// text — kept separate from Notes (your own writing).
    @Relationship(deleteRule: .cascade, inverse: \TopicMaterial.topic)
    var material: [TopicMaterial] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        createdAt: Date = .now,
        sortIndex: Int = 0,
        schoolClass: SchoolClass? = nil,
        isSummerWork: Bool = false
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.schoolClass = schoolClass
        self.isSummerWork = isSummerWork
    }
}

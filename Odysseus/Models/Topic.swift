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
    /// Last time this topic was marked reviewed during March Exam prep.
    var lastReviewedAt: Date?
    /// How many times it's been reviewed — advances which spaced-repetition
    /// interval is used for the next one (see `nextReviewDate`).
    var reviewCount: Int = 0

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
        schoolClass: SchoolClass? = nil,
        lastReviewedAt: Date? = nil,
        reviewCount: Int = 0
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.sortIndex = sortIndex
        self.schoolClass = schoolClass
        self.lastReviewedAt = lastReviewedAt
        self.reviewCount = reviewCount
    }
}

extension Topic {
    /// Expanding spaced-repetition schedule — each review pushes the next
    /// one further out (3 days → 1wk → 2wk → 1mo → 2mo), refreshing memory
    /// of a topic covered early in the term all the way through exam prep,
    /// the way spaced review actually works, rather than one flat interval.
    private static let reviewIntervalsDays = [3, 7, 14, 30, 60]

    /// When this topic is next due for review, or nil if it's already
    /// covered closely enough to the given exam date that no further review
    /// is needed.
    func nextReviewDate(examDate: Date?) -> Date? {
        let base = lastReviewedAt ?? createdAt
        let intervalDays = Self.reviewIntervalsDays[min(reviewCount, Self.reviewIntervalsDays.count - 1)]
        guard let due = Calendar.current.date(byAdding: .day, value: intervalDays, to: base) else { return nil }
        if let examDate, due > examDate { return nil }
        return due
    }

    func markReviewed() {
        lastReviewedAt = .now
        reviewCount += 1
    }
}

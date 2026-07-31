//
//  Exam.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class Exam {
    var id: String
    /// Free-form so it covers anything — "SAT", "March SAT", "AP Calculus BC", "ACT June".
    var name: String
    var examDate: Date
    var targetScore: String?
    var notes: String?
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \StudySession.exam)
    var studySessions: [StudySession] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        examDate: Date,
        targetScore: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.examDate = examDate
        self.targetScore = targetScore
        self.notes = notes
        self.createdAt = createdAt
    }

    var daysUntil: Int {
        let today = Calendar.current.startOfDay(for: .now)
        let target = Calendar.current.startOfDay(for: examDate)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var isPast: Bool { daysUntil < 0 }
}

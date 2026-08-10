//
//  Exam.swift
//  Odysseus
//

import Foundation
import SwiftData

enum ExamCategory: String, Codable, CaseIterable, Identifiable {
    case act
    case marchExams
    case apExams

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .act: return "ACT"
        case .marchExams: return "March Exams"
        case .apExams: return "AP Exams"
        }
    }
}

@Model
final class Exam {
    var id: String
    /// Free-form so it covers anything — "SAT", "March SAT", "AP Calculus BC", "ACT June".
    var name: String
    var examDate: Date
    var targetScore: String?
    var notes: String?
    var createdAt: Date
    var schoolClass: SchoolClass?
    var categoryRaw: String
    /// The real score once it's back — free-form since ACT (1-36), AP (1-5), and
    /// class tests (percentage/points) all mean different things.
    var actualScore: String?
    var scoreLoggedAt: Date?
    /// Defaults on (unlike assignments/tasks) — a test date is high-stakes
    /// enough that most people want the reminder without having to opt in.
    var remindersOn: Bool

    @Relationship(deleteRule: .cascade, inverse: \StudySession.exam)
    var studySessions: [StudySession] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        examDate: Date,
        targetScore: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        schoolClass: SchoolClass? = nil,
        category: ExamCategory = .marchExams,
        actualScore: String? = nil,
        scoreLoggedAt: Date? = nil,
        remindersOn: Bool = true
    ) {
        self.id = id
        self.name = name
        self.examDate = examDate
        self.targetScore = targetScore
        self.notes = notes
        self.createdAt = createdAt
        self.schoolClass = schoolClass
        self.categoryRaw = category.rawValue
        self.actualScore = actualScore
        self.scoreLoggedAt = scoreLoggedAt
        self.remindersOn = remindersOn
    }

    var category: ExamCategory {
        get { ExamCategory(rawValue: categoryRaw) ?? .marchExams }
        set { categoryRaw = newValue.rawValue }
    }

    var daysUntil: Int {
        let today = Calendar.current.startOfDay(for: .now)
        let target = Calendar.current.startOfDay(for: examDate)
        return Calendar.current.dateComponents([.day], from: today, to: target).day ?? 0
    }

    var isPast: Bool { daysUntil < 0 }
    var hasScore: Bool { actualScore != nil && !(actualScore ?? "").isEmpty }
}

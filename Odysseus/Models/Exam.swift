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
    var id: String = UUID().uuidString
    /// Free-form so it covers anything — "SAT", "March SAT", "AP Calculus BC", "ACT June".
    var name: String = ""
    var examDate: Date = Date.now
    var targetScore: String?
    var notes: String?
    var createdAt: Date = Date.now
    var schoolClass: SchoolClass?
    var categoryRaw: String = ExamCategory.marchExams.rawValue
    /// The real score once it's back — free-form since ACT (1-36), AP (1-5), and
    /// class tests (percentage/points) all mean different things.
    var actualScore: String?
    var scoreLoggedAt: Date?
    /// Defaults on (unlike assignments/tasks) — a test date is high-stakes
    /// enough that most people want the reminder without having to opt in.
    var remindersOn: Bool = true
    /// Points-based score for a class's March Exam — feeds into that class's
    /// overall calculated grade (see `SchoolClass.calculatedPercent`) at its
    /// configured exam weight. Not used for ACT/AP, which have their own
    /// native scales (`actualScore` free text, or `ACTSectionScore`).
    var pointsEarned: Double?
    var pointsPossible: Double?

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
        remindersOn: Bool = true,
        pointsEarned: Double? = nil,
        pointsPossible: Double? = nil
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
        self.pointsEarned = pointsEarned
        self.pointsPossible = pointsPossible
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

    /// This exam's own percentage, when logged with a points-based score.
    var calculatedPercent: Double? {
        guard let earned = pointsEarned, let possible = pointsPossible, possible > 0 else { return nil }
        return (earned / possible) * 100
    }
}

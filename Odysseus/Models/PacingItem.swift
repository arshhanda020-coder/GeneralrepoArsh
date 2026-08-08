//
//  PacingItem.swift
//  Odysseus
//
//  One dated item (a review, a practice assignment, homework, or a practice
//  test) from an AI-generated pacing plan for a March Exams-category exam —
//  spread across the whole runway to the exam, not just a cram week, so
//  material stays fresh instead of being forgotten right after it's covered.
//

import Foundation
import SwiftData

enum PacingItemKind: String, Codable, CaseIterable, Identifiable {
    case review, assignment, homework, test

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .review: return "Review"
        case .assignment: return "Assignment"
        case .homework: return "Homework"
        case .test: return "Practice Test"
        }
    }
}

@Model
final class PacingItem {
    var id: String
    var exam: Exam?
    var title: String
    var detail: String?
    var kindRaw: String
    var scheduledDate: Date
    var isDone: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        exam: Exam? = nil,
        title: String,
        detail: String? = nil,
        kind: PacingItemKind,
        scheduledDate: Date,
        isDone: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.exam = exam
        self.title = title
        self.detail = detail
        self.kindRaw = kind.rawValue
        self.scheduledDate = scheduledDate
        self.isDone = isDone
        self.createdAt = createdAt
    }

    var kind: PacingItemKind {
        get { PacingItemKind(rawValue: kindRaw) ?? .review }
        set { kindRaw = newValue.rawValue }
    }
}

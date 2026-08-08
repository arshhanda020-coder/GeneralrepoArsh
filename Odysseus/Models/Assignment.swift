//
//  Assignment.swift
//  Odysseus
//

import Foundation
import SwiftData

enum AssignmentType: String, Codable, CaseIterable, Identifiable {
    case assignment
    case quiz
    case test
    case project

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .assignment: return "Assignment"
        case .quiz: return "Quiz"
        case .test: return "Test"
        case .project: return "Project"
        }
    }
}

@Model
final class Assignment {
    var id: String
    var title: String
    var dueDate: Date?
    var isDone: Bool
    var notes: String?
    var createdAt: Date
    var topic: Topic?
    /// Denormalized alongside `topic` so grade math can total a class's work
    /// without walking every topic — set to topic?.schoolClass for anything
    /// added under a topic, or chosen directly for mock what-if entries
    /// (which have no topic at all).
    var schoolClass: SchoolClass?
    /// nil = not marked yet, true = "I understand", false = "Help me understand" was used.
    var understood: Bool?
    /// The AI's explanation from the last "Help me understand" tap.
    var helpExplanation: String?
    var remindersOn: Bool
    var typeRaw: String
    /// Points actually scored, once graded.
    var pointsEarned: Double?
    /// Points the item was out of. Both this and pointsEarned need to be set for it to count toward a class grade.
    var pointsPossible: Double?
    /// Optional photo of the assignment/rubric/graded paper — never required, just there if you want it for reference or to ask AI for help.
    var photoData: Data?
    /// A hypothetical "what if I get an X on this" entry for GPA projection —
    /// counts toward the Projected grade in the GPA Calculator but never the
    /// real one, and never shows up on the Calendar or in study plans.
    var isMock: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        dueDate: Date? = nil,
        isDone: Bool = false,
        notes: String? = nil,
        createdAt: Date = .now,
        topic: Topic? = nil,
        schoolClass: SchoolClass? = nil,
        understood: Bool? = nil,
        helpExplanation: String? = nil,
        remindersOn: Bool = false,
        type: AssignmentType = .assignment,
        pointsEarned: Double? = nil,
        pointsPossible: Double? = nil,
        photoData: Data? = nil,
        isMock: Bool = false
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.notes = notes
        self.createdAt = createdAt
        self.topic = topic
        self.schoolClass = schoolClass ?? topic?.schoolClass
        self.understood = understood
        self.helpExplanation = helpExplanation
        self.remindersOn = remindersOn
        self.typeRaw = type.rawValue
        self.pointsEarned = pointsEarned
        self.pointsPossible = pointsPossible
        self.photoData = photoData
        self.isMock = isMock
    }

    var type: AssignmentType {
        get { AssignmentType(rawValue: typeRaw) ?? .assignment }
        set { typeRaw = newValue.rawValue }
    }

    var isGraded: Bool {
        guard let pointsPossible else { return false }
        return pointsEarned != nil && pointsPossible > 0
    }

    var percentScore: Double? {
        guard isGraded, let pointsEarned, let pointsPossible else { return nil }
        return pointsEarned / pointsPossible * 100
    }

    /// Fall/Spring, derived from the due date (or when it was logged, if no due date was set).
    var term: SchoolTerm { SchoolTerm.term(for: dueDate ?? createdAt) }
}

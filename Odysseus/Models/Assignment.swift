//
//  Assignment.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class Assignment {
    var id: String = UUID().uuidString
    var title: String = ""
    var dueDate: Date?
    var isDone: Bool = false
    var notes: String?
    var createdAt: Date = Date.now
    var lesson: Lesson?
    /// Distinguishes a test/quiz from regular homework within a lesson —
    /// same model, just a different badge and a different "Add" entry point.
    var isQuiz: Bool = false
    /// nil = not marked yet, true = "I understand", false = "Help me understand" was used.
    var understood: Bool?
    /// The AI's explanation from the last "Help me understand" tap.
    var helpExplanation: String?
    var remindersOn: Bool = false
    /// Points-based score — e.g. 8/10. Both nil until graded. Feeds the
    /// class's overall grade automatically (see `SchoolClass.calculatedGradeLabel`),
    /// which in turn drives the GPA Calculator.
    var pointsEarned: Double?
    var pointsPossible: Double?

    init(
        id: String = UUID().uuidString,
        title: String,
        dueDate: Date? = nil,
        isDone: Bool = false,
        notes: String? = nil,
        createdAt: Date = .now,
        lesson: Lesson? = nil,
        isQuiz: Bool = false,
        understood: Bool? = nil,
        helpExplanation: String? = nil,
        remindersOn: Bool = false,
        pointsEarned: Double? = nil,
        pointsPossible: Double? = nil
    ) {
        self.id = id
        self.title = title
        self.dueDate = dueDate
        self.isDone = isDone
        self.notes = notes
        self.createdAt = createdAt
        self.lesson = lesson
        self.isQuiz = isQuiz
        self.understood = understood
        self.helpExplanation = helpExplanation
        self.remindersOn = remindersOn
        self.pointsEarned = pointsEarned
        self.pointsPossible = pointsPossible
    }
}

extension Assignment {
    var isGraded: Bool {
        guard let possible = pointsPossible, possible > 0, pointsEarned != nil else { return false }
        return true
    }

    var scoreLabel: String? {
        guard let earned = pointsEarned, let possible = pointsPossible, possible > 0 else { return nil }
        func format(_ value: Double) -> String {
            value.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(value)) : String(value)
        }
        return "\(format(earned))/\(format(possible))"
    }
}

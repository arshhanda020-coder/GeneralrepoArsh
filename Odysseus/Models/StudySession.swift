//
//  StudySession.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class StudySession {
    var id: String
    var date: Date
    var note: String?
    /// Free-form; ACT logging uses "English"/"Math"/"Reading"/"Science"/"General".
    var subjectArea: String?
    var durationMinutes: Int?
    var exam: Exam?

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        note: String? = nil,
        subjectArea: String? = nil,
        durationMinutes: Int? = nil,
        exam: Exam? = nil
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.subjectArea = subjectArea
        self.durationMinutes = durationMinutes
        self.exam = exam
    }
}

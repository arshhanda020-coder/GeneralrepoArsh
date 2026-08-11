//
//  StudySession.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class StudySession {
    var id: String = UUID().uuidString
    var date: Date = Date.now
    var note: String?
    /// Free-form; ACT logging uses "English"/"Math"/"Reading"/"Science"/"General".
    var subjectArea: String?
    var durationMinutes: Int?
    var exam: Exam?
    /// Optional screenshot attached to the session — e.g. a practice-test
    /// score report or a page of notes, for ACT/AP session logging.
    var screenshotData: Data?

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        note: String? = nil,
        subjectArea: String? = nil,
        durationMinutes: Int? = nil,
        exam: Exam? = nil,
        screenshotData: Data? = nil
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.subjectArea = subjectArea
        self.durationMinutes = durationMinutes
        self.exam = exam
        self.screenshotData = screenshotData
    }
}

//
//  StudySession.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class StudySession {
    var date: Date
    var note: String?
    var exam: Exam?

    init(date: Date = .now, note: String? = nil, exam: Exam? = nil) {
        self.date = date
        self.note = note
        self.exam = exam
    }
}

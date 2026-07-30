//
//  Completion.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class Completion {
    var date: Date
    var note: String?
    var imageData: Data?
    var habit: Habit?

    init(date: Date, note: String? = nil, imageData: Data? = nil, habit: Habit? = nil) {
        self.date = Calendar.current.startOfDay(for: date)
        self.note = note
        self.imageData = imageData
        self.habit = habit
    }
}

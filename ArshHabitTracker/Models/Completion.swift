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
    /// Macro fields — only meaningful for meal-category habits, nil otherwise.
    var calories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    var habit: Habit?

    init(
        date: Date,
        note: String? = nil,
        imageData: Data? = nil,
        calories: Int? = nil,
        proteinGrams: Double? = nil,
        carbsGrams: Double? = nil,
        fatGrams: Double? = nil,
        habit: Habit? = nil
    ) {
        self.date = Calendar.current.startOfDay(for: date)
        self.note = note
        self.imageData = imageData
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.habit = habit
    }

    var hasMacros: Bool {
        calories != nil || proteinGrams != nil || carbsGrams != nil || fatGrams != nil
    }
}

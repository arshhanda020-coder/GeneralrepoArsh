//
//  Habit.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class Habit {
    var id: String
    var name: String
    var emoji: String
    var colorHex: String
    var categoryRaw: String
    var createdAt: Date
    /// 1 = Sunday ... 7 = Saturday. Empty means every day.
    var scheduledDays: [Int]
    var remindersOn: Bool
    var reminderHour: Int
    var reminderMinute: Int

    @Relationship(deleteRule: .cascade, inverse: \Completion.habit)
    var completions: [Completion] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        emoji: String,
        colorHex: String,
        category: HabitCategory,
        createdAt: Date = .now,
        scheduledDays: [Int] = [],
        remindersOn: Bool = false,
        reminderHour: Int = 8,
        reminderMinute: Int = 0
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.categoryRaw = category.rawValue
        self.createdAt = createdAt
        self.scheduledDays = scheduledDays
        self.remindersOn = remindersOn
        self.reminderHour = reminderHour
        self.reminderMinute = reminderMinute
    }

    var category: HabitCategory {
        get { HabitCategory(rawValue: categoryRaw) ?? .newHabits }
        set { categoryRaw = newValue.rawValue }
    }
}

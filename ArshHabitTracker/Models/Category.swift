//
//  Category.swift
//  ArshHabitTracker
//

import SwiftUI

enum HabitCategory: String, Codable, CaseIterable, Identifiable {
    case school
    case workouts
    case meals
    case skincare
    case newHabits
    case accounting

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .school: return "School"
        case .workouts: return "Workouts"
        case .meals: return "Meals"
        case .skincare: return "Skincare"
        case .newHabits: return "New Habits"
        case .accounting: return "Accounting"
        }
    }

    var emoji: String {
        switch self {
        case .school: return "🎓"
        case .workouts: return "💪"
        case .meals: return "🍽️"
        case .skincare: return "✨"
        case .newHabits: return "🌱"
        case .accounting: return "💰"
        }
    }

    var accentHex: String {
        switch self {
        case .school: return "5C7A99"
        case .workouts: return "8E7B5E"
        case .meals: return "9C8F6E"
        case .skincare: return "9C8A96"
        case .newHabits: return "7FA285"
        case .accounting: return "B8935B"
        }
    }

    var accentColor: Color { Color(hex: accentHex) }

    /// Meals and workouts are logged with a note/photo rather than a simple check-off.
    var isLoggingType: Bool { self == .meals || self == .workouts }
}

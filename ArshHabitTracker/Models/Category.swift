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
        case .school: return "5B8CFF"
        case .workouts: return "FF6B6B"
        case .meals: return "FFB84D"
        case .skincare: return "FF8FD1"
        case .newHabits: return "4ADE80"
        case .accounting: return "A78BFA"
        }
    }

    var accentColor: Color { Color(hex: accentHex) }

    /// Meals are logged with a note rather than a simple check-off.
    var isLoggingType: Bool { self == .meals }
}

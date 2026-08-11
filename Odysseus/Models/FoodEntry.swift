//
//  FoodEntry.swift
//  Odysseus
//
//  A single logged meal/snack — flat entries, not tied to a template, so
//  logging breakfast/lunch/dinner/snacks multiple times a day just works.
//  mealType groups entries into a MyFitnessPal-style diary without forcing
//  one entry per meal per day.
//

import Foundation
import SwiftData

@Model
final class FoodEntry {
    var id: String = UUID().uuidString
    var date: Date = .now
    var note: String = ""
    var imageData: Data?
    var calories: Int?
    var proteinGrams: Double?
    var carbsGrams: Double?
    var fatGrams: Double?
    /// Raw MealType.rawValue. Optional so pre-existing entries (logged before
    /// meal types existed) still load fine — they just show up as "Snacks".
    var mealTypeRaw: String?

    var mealType: MealType {
        get { MealType(rawValue: mealTypeRaw ?? "") ?? .snack }
        set { mealTypeRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        note: String,
        imageData: Data? = nil,
        calories: Int? = nil,
        proteinGrams: Double? = nil,
        carbsGrams: Double? = nil,
        fatGrams: Double? = nil,
        mealType: MealType = .snack
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.imageData = imageData
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
        self.mealTypeRaw = mealType.rawValue
    }
}

enum MealType: String, CaseIterable, Identifiable, Codable {
    case breakfast = "Breakfast"
    case lunch = "Lunch"
    case dinner = "Dinner"
    case snack = "Snacks"

    var id: String { rawValue }

    var symbolName: String {
        switch self {
        case .breakfast: return "sunrise.fill"
        case .lunch: return "sun.max.fill"
        case .dinner: return "moon.stars.fill"
        case .snack: return "leaf.fill"
        }
    }

    /// Smart default when logging without picking a section explicitly —
    /// same "guess the meal from the clock" convenience Cal AI/MFP have.
    static func forCurrentTime(_ date: Date = .now) -> MealType {
        let hour = Calendar.current.component(.hour, from: date)
        switch hour {
        case 4..<11: return .breakfast
        case 11..<16: return .lunch
        case 16..<21: return .dinner
        default: return .snack
        }
    }
}

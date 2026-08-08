//
//  FoodEntry.swift
//  Odysseus
//
//  A single logged meal/snack — flat entries, not tied to a template, so
//  logging breakfast/lunch/dinner/snacks multiple times a day just works.
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

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        note: String,
        imageData: Data? = nil,
        calories: Int? = nil,
        proteinGrams: Double? = nil,
        carbsGrams: Double? = nil,
        fatGrams: Double? = nil
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.imageData = imageData
        self.calories = calories
        self.proteinGrams = proteinGrams
        self.carbsGrams = carbsGrams
        self.fatGrams = fatGrams
    }
}

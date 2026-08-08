//
//  WorkoutEntry.swift
//  Odysseus
//
//  A single logged workout — flat entries, not tied to a template.
//

import Foundation
import SwiftData

@Model
final class WorkoutEntry {
    var id: String
    var date: Date
    var note: String
    var imageData: Data?
    var durationMinutes: Int?
    var caloriesBurned: Int?

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        note: String,
        imageData: Data? = nil,
        durationMinutes: Int? = nil,
        caloriesBurned: Int? = nil
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.imageData = imageData
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
    }
}

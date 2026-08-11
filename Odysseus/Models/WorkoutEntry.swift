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
    var id: String = UUID().uuidString
    var date: Date = .now
    var note: String = ""
    var imageData: Data?
    var durationMinutes: Int?
    var caloriesBurned: Int?
    /// 1 (light) ... 5 (max effort). Nil for old entries logged before intensity existed.
    var intensityRaw: Int?
    /// True when caloriesBurned came from the local MET fallback (AI call failed/unavailable)
    /// rather than an AI estimate — surfaced in the UI as a rougher number.
    var isEstimateFallback: Bool

    init(
        id: String = UUID().uuidString,
        date: Date = .now,
        note: String,
        imageData: Data? = nil,
        durationMinutes: Int? = nil,
        caloriesBurned: Int? = nil,
        intensity: WorkoutIntensity? = nil,
        isEstimateFallback: Bool = false
    ) {
        self.id = id
        self.date = date
        self.note = note
        self.imageData = imageData
        self.durationMinutes = durationMinutes
        self.caloriesBurned = caloriesBurned
        self.intensityRaw = intensity?.rawValue
        self.isEstimateFallback = isEstimateFallback
    }

    var intensity: WorkoutIntensity? {
        get { intensityRaw.flatMap(WorkoutIntensity.init(rawValue:)) }
        set { intensityRaw = newValue?.rawValue }
    }
}

/// How hard the activity felt — feeds the calorie-burn estimate alongside
/// duration and body stats.
enum WorkoutIntensity: Int, CaseIterable, Identifiable {
    case light = 1
    case easy = 2
    case moderate = 3
    case hard = 4
    case maxEffort = 5

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .light: return "Light"
        case .easy: return "Easy"
        case .moderate: return "Moderate"
        case .hard: return "Hard"
        case .maxEffort: return "Max effort"
        }
    }

    /// Rough MET (metabolic equivalent) value per level, used as the local
    /// fallback formula when AI estimation isn't available.
    var met: Double {
        switch self {
        case .light: return 3.0
        case .easy: return 4.5
        case .moderate: return 6.0
        case .hard: return 8.0
        case .maxEffort: return 10.5
        }
    }
}

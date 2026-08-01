//
//  ActivitySession.swift
//  ArshHabitTracker
//
//  A timed activity (e.g. a pickup basketball game) — duration comes from the
//  stopwatch, calories burned comes from an AI estimate based on duration +
//  a couple of quick qualitative questions.
//

import Foundation
import SwiftData

@Model
final class ActivitySession {
    var id: String
    var activityName: String
    var startedAt: Date
    var durationSeconds: Int
    /// 1 (light) ... 5 (max effort)
    var intensity: Int
    /// 1 (barely) ... 5 (drenched)
    var sweatLevel: Int
    var estimatedCalories: Int?
    var notes: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        activityName: String,
        startedAt: Date,
        durationSeconds: Int,
        intensity: Int,
        sweatLevel: Int,
        estimatedCalories: Int? = nil,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.activityName = activityName
        self.startedAt = startedAt
        self.durationSeconds = durationSeconds
        self.intensity = intensity
        self.sweatLevel = sweatLevel
        self.estimatedCalories = estimatedCalories
        self.notes = notes
        self.createdAt = createdAt
    }
}

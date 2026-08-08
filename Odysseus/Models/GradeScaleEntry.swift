//
//  GradeScaleEntry.swift
//  Odysseus
//
//  The user's own grading scale (e.g. "A" -> 4.0, 93-96%) — auto-seeded from
//  Rutgers Prep's published chart, but nothing stops it being edited or
//  replaced since scales vary by school. minPercent/maxPercent are what let
//  a class's raw points-earned/points-possible resolve to a letter grade
//  automatically.
//

import Foundation
import SwiftData

@Model
final class GradeScaleEntry {
    var id: String
    var label: String
    var points: Double
    var sortIndex: Int
    var minPercent: Double?
    var maxPercent: Double?

    init(id: String = UUID().uuidString, label: String, points: Double, sortIndex: Int = 0, minPercent: Double? = nil, maxPercent: Double? = nil) {
        self.id = id
        self.label = label
        self.points = points
        self.sortIndex = sortIndex
        self.minPercent = minPercent
        self.maxPercent = maxPercent
    }
}

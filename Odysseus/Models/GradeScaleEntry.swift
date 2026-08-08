//
//  GradeScaleEntry.swift
//  Odysseus
//
//  The user's own grading scale (e.g. "A" -> 4.0) — nothing is assumed or
//  seeded, since scales vary a lot by school.
//

import Foundation
import SwiftData

@Model
final class GradeScaleEntry {
    var id: String
    var label: String
    var points: Double
    var sortIndex: Int

    init(id: String = UUID().uuidString, label: String, points: Double, sortIndex: Int = 0) {
        self.id = id
        self.label = label
        self.points = points
        self.sortIndex = sortIndex
    }
}

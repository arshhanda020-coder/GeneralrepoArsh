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
    var id: String = UUID().uuidString
    var label: String = ""
    var points: Double = 0
    var sortIndex: Int = 0

    init(id: String = UUID().uuidString, label: String, points: Double, sortIndex: Int = 0) {
        self.id = id
        self.label = label
        self.points = points
        self.sortIndex = sortIndex
    }
}

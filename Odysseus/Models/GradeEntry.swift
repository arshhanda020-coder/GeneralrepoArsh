//
//  GradeEntry.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class GradeEntry {
    var id: String
    var courseName: String
    /// Matched against a GradeScaleEntry.label to resolve GPA points.
    var gradeLabel: String
    var credits: Double
    /// Honors/AP — gets GPASettings.honorsBonus added on top when computing weighted GPA.
    var isWeighted: Bool
    var term: String?
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        courseName: String,
        gradeLabel: String,
        credits: Double = 1.0,
        isWeighted: Bool = false,
        term: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.courseName = courseName
        self.gradeLabel = gradeLabel
        self.credits = credits
        self.isWeighted = isWeighted
        self.term = term
        self.createdAt = createdAt
    }
}

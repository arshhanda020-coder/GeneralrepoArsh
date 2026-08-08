//
//  SchoolClass.swift
//  Odysseus
//

import Foundation
import SwiftData

enum GradeWeightOverride: String, Codable, CaseIterable, Identifiable {
    case auto, none, honors, ap
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .auto: return "Auto (from class name)"
        case .none: return "None"
        case .honors: return "Honors"
        case .ap: return "AP"
        }
    }
}

@Model
final class SchoolClass {
    var id: String
    var name: String
    var isEnrolled: Bool
    var sortIndex: Int
    var createdAt: Date
    /// Used as the weight in GPA math — most schools count every class the same (1.0).
    var credits: Double
    /// nil/"auto" guesses Honors/AP from the class name; set explicitly to override.
    var weightOverrideRaw: String?
    /// Escape hatch for a class with no graded work logged yet — set a grade
    /// percentage directly instead of waiting on assignment points.
    var manualPercentOverride: Double?

    @Relationship(deleteRule: .cascade, inverse: \Topic.schoolClass)
    var topics: [Topic] = []

    /// Every graded (or mock) assignment attributed to this class, whether it
    /// hangs off one of its topics or was added directly (mock what-if
    /// entries have no topic) — the source of truth for grade math.
    @Relationship(deleteRule: .cascade, inverse: \Assignment.schoolClass)
    var directAssignments: [Assignment] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        isEnrolled: Bool = true,
        sortIndex: Int = 0,
        createdAt: Date = .now,
        credits: Double = 1.0,
        weightOverride: GradeWeightOverride = .auto,
        manualPercentOverride: Double? = nil
    ) {
        self.id = id
        self.name = name
        self.isEnrolled = isEnrolled
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.credits = credits
        self.weightOverrideRaw = weightOverride == .auto ? nil : weightOverride.rawValue
        self.manualPercentOverride = manualPercentOverride
    }

    var weightOverride: GradeWeightOverride {
        get { weightOverrideRaw.flatMap(GradeWeightOverride.init) ?? .auto }
        set { weightOverrideRaw = newValue == .auto ? nil : newValue.rawValue }
    }

    /// (isWeighted, isAP) after resolving an explicit override or falling back to guessing from the name.
    var resolvedWeight: (isWeighted: Bool, isAP: Bool) {
        switch weightOverride {
        case .none: return (false, false)
        case .honors: return (true, false)
        case .ap: return (true, true)
        case .auto: return GPASettings.suggestedWeight(for: name)
        }
    }

    struct GradeSummary {
        var pointsEarned: Double = 0
        var pointsPossible: Double = 0
        var isManual = false

        var percent: Double? {
            guard pointsPossible > 0 else { return nil }
            return pointsEarned / pointsPossible * 100
        }
    }

    /// Totals graded work into a percentage. `includeMock` folds in what-if
    /// entries too, for the GPA Calculator's Projected column. Summer Work
    /// is always excluded — it's never graded, by design. `term` scopes to
    /// Fall/Spring (or everything, for .fullYear).
    func gradeSummary(includeMock: Bool, term: SchoolTerm = .fullYear) -> GradeSummary {
        let items = directAssignments.filter {
            $0.isGraded && (includeMock || !$0.isMock) && $0.topic?.isSummerWork != true && term.matches($0.dueDate ?? $0.createdAt)
        }
        guard !items.isEmpty else {
            if let manualPercentOverride {
                return GradeSummary(pointsEarned: manualPercentOverride, pointsPossible: 100, isManual: true)
            }
            return GradeSummary()
        }
        let earned = items.reduce(0) { $0 + ($1.pointsEarned ?? 0) }
        let possible = items.reduce(0) { $0 + ($1.pointsPossible ?? 0) }
        return GradeSummary(pointsEarned: earned, pointsPossible: possible)
    }
}

//
//  GPASettings.swift
//  Odysseus
//

import Foundation
import SwiftData

nonisolated enum GPASettings {
    private static let bonusKey = "gpa_honors_bonus"
    private static let apBonusKey = "gpa_ap_bonus"

    /// Added on top of a grade's scale points for courses marked Honors.
    static var honorsBonus: Double {
        get { (UserDefaults.standard.object(forKey: bonusKey) as? Double) ?? 1.0 / 3.0 }
        set { UserDefaults.standard.set(newValue, forKey: bonusKey) }
    }

    /// Added on top of a grade's scale points for courses marked AP — bigger
    /// than the Honors bump, matching how most weighted scales work.
    static var apBonus: Double {
        get { (UserDefaults.standard.object(forKey: apBonusKey) as? Double) ?? 2.0 / 3.0 }
        set { UserDefaults.standard.set(newValue, forKey: apBonusKey) }
    }

    /// Rutgers Preparatory School's Upper School grading scale (percentage
    /// band, unweighted GPA points), from its published curriculum guide —
    /// Honors adds honorsBonus, AP adds apBonus on top of these base points.
    /// Only a starting point: edit or replace any row in the GPA Calculator
    /// if your own report card lists something different.
    static let rutgersPrepScale: [(label: String, points: Double, minPercent: Double, maxPercent: Double)] = [
        ("A+", 4.333, 97, 100), ("A", 4.0, 93, 96.999), ("A-", 3.667, 90, 92.999),
        ("B+", 3.333, 87, 89.999), ("B", 3.0, 83, 86.999), ("B-", 2.667, 80, 82.999),
        ("C+", 2.333, 77, 79.999), ("C", 2.0, 73, 76.999), ("C-", 1.667, 70, 72.999),
        ("D+", 1.333, 67, 69.999), ("D", 1.0, 63, 66.999), ("D-", 0.667, 60, 62.999),
        ("F", 0.0, 0, 59.999)
    ]

    /// Populates the grading scale with Rutgers Prep's chart and resets the
    /// Honors/AP bumps to its published values — additive to whatever scale
    /// entries already exist (doesn't touch or duplicate rows with the same
    /// label).
    @MainActor
    static func seedRutgersPrepScale(into context: ModelContext, existing: [GradeScaleEntry]) {
        var nextIndex = (existing.map(\.sortIndex).max() ?? -1) + 1
        for row in rutgersPrepScale where !existing.contains(where: { $0.label.caseInsensitiveCompare(row.label) == .orderedSame }) {
            context.insert(GradeScaleEntry(label: row.label, points: row.points, sortIndex: nextIndex, minPercent: row.minPercent, maxPercent: row.maxPercent))
            nextIndex += 1
        }
        honorsBonus = 1.0 / 3.0
        apBonus = 2.0 / 3.0
    }

    /// Resolves a raw percentage to a scale row via its min/maxPercent band, for classes graded by points.
    static func scaleEntry(forPercent percent: Double, in scaleEntries: [GradeScaleEntry]) -> GradeScaleEntry? {
        scaleEntries.first { entry in
            guard let min = entry.minPercent, let max = entry.maxPercent else { return false }
            return percent >= min && percent <= max
        }
    }

    /// Guesses Honors/AP weighting from a class name (e.g. "AP Biology",
    /// "Honors Precalc") so adding a class doesn't require re-declaring what
    /// you already named it — always overridable per-class.
    static func suggestedWeight(for className: String) -> (isWeighted: Bool, isAP: Bool) {
        let name = className.lowercased()
        if name.contains("ap ") || name.hasPrefix("ap") || name.contains("(ap)") {
            return (true, true)
        }
        if name.contains("honors") {
            return (true, false)
        }
        return (false, false)
    }
}

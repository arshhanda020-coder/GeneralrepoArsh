//
//  SchoolClass.swift
//  Odysseus
//

import Foundation
import SwiftData

/// A class's weighting tier for GPA purposes. Auto-detected from the course
/// name — Rutgers Prep's own course titles already say "AP ..." or
/// "Honors ..." — so nothing needs to be entered by hand. See
/// `RutgersPrepGPA` for the official weighting bump each tier carries.
enum CourseLevel: String, Codable, CaseIterable, Identifiable {
    case regular, honors, ap

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .regular: return "Regular"
        case .honors: return "Honors"
        case .ap: return "AP"
        }
    }

    /// Reads the level straight off a Rutgers Prep course title, the way
    /// they label it themselves (e.g. "AP Computer Science", "Honors French 3").
    static func detect(from name: String) -> CourseLevel {
        let upper = name.uppercased()
        if upper.hasPrefix("AP ") || upper.contains(" AP ") || upper.contains("(AP)") || upper.hasSuffix(" AP") {
            return .ap
        }
        if upper.hasPrefix("HONORS") || upper.contains(" HONORS") || upper.hasPrefix("ENRICHED ") {
            return .honors
        }
        return .regular
    }
}

@Model
final class SchoolClass {
    var id: String = UUID().uuidString
    var name: String = ""
    var isEnrolled: Bool = true
    var sortIndex: Int = 0
    var createdAt: Date = Date.now

    /// Index into `ClassBannerColor.allCases`, or -1 for "not chosen yet" —
    /// falls back to a stable auto-assigned color (see `bannerColor` below)
    /// so every class still gets a distinct Classroom-style banner color
    /// without the user having to pick one.
    var colorIndex: Int = -1

    /// Manually-set fallback letter grade — only used while a class has no
    /// graded assignments/tests yet to calculate one from. Once points are
    /// logged, `calculatedGradeLabel` takes over automatically (see below).
    var gradeLabel: String?

    /// Set only when the auto-detected level (from the class name) is wrong
    /// for some reason and the student corrects it by hand. Leave nil to
    /// stay fully automatic.
    var courseLevelOverrideRaw: String?

    var courseLevel: CourseLevel {
        get { courseLevelOverrideRaw.flatMap(CourseLevel.init) ?? CourseLevel.detect(from: name) }
        set { courseLevelOverrideRaw = newValue.rawValue }
    }

    @Relationship(deleteRule: .cascade, inverse: \Topic.schoolClass)
    var topics: [Topic] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        isEnrolled: Bool = true,
        sortIndex: Int = 0,
        createdAt: Date = .now,
        colorIndex: Int = -1,
        gradeLabel: String? = nil,
        courseLevelOverrideRaw: String? = nil
    ) {
        self.id = id
        self.name = name
        self.isEnrolled = isEnrolled
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.colorIndex = colorIndex
        self.gradeLabel = gradeLabel
        self.courseLevelOverrideRaw = courseLevelOverrideRaw
    }
}

extension SchoolClass {
    /// The class's banner color — whatever was explicitly picked, or a
    /// stable auto-assignment hashed from the class's id so it stays put
    /// across relaunches until the user chooses one themselves.
    var bannerColor: ClassBannerColor {
        if colorIndex >= 0, let picked = ClassBannerColor(rawValue: colorIndex) {
            return picked
        }
        return .auto(for: id)
    }

    /// Every graded assignment/test-quiz across every lesson in every topic.
    var gradedAssignments: [Assignment] {
        topics.flatMap { $0.lessons.flatMap(\.assignments) }.filter(\.isGraded)
    }

    /// Sum of points earned/possible across every graded item — the raw
    /// input to the class's calculated percentage.
    var gradedPoints: (earned: Double, possible: Double)? {
        let items = gradedAssignments
        guard !items.isEmpty else { return nil }
        let earned = items.reduce(0.0) { $0 + ($1.pointsEarned ?? 0) }
        let possible = items.reduce(0.0) { $0 + ($1.pointsPossible ?? 0) }
        guard possible > 0 else { return nil }
        return (earned, possible)
    }

    /// The class's overall percentage, calculated automatically from every
    /// graded assignment and test/quiz logged so far.
    var calculatedPercent: Double? {
        guard let points = gradedPoints else { return nil }
        return (points.earned / points.possible) * 100
    }

    /// The letter grade Rutgers Prep's table maps `calculatedPercent` to.
    var calculatedGradeLabel: String? {
        calculatedPercent.flatMap(RutgersPrepGPA.label(forPercent:))
    }

    /// The grade actually used everywhere (class page, GPA Calculator) —
    /// auto-calculated from logged points once any exist, falling back to
    /// the manually-set `gradeLabel` only until then.
    var effectiveGradeLabel: String? {
        calculatedGradeLabel ?? gradeLabel
    }

    /// True once the effective grade comes from real logged points rather
    /// than a manual fallback pick.
    var hasCalculatedGrade: Bool { calculatedGradeLabel != nil }
}

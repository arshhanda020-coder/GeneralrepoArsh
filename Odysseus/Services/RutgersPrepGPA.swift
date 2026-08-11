//
//  RutgersPrepGPA.swift
//  Odysseus
//
//  Rutgers Prep's official GPA policy, so the GPA Calculator needs zero
//  manual setup — no building a grading scale by hand, no flagging Honors/AP
//  per class. The standard 4.0 letter-grade scale plus Rutgers Prep's own
//  Honors/AP weighting bump (per the Upper School Curriculum Guide: Honors
//  gets a one-third bump, AP gets a two-thirds bump) are baked in here, and
//  each class's level is auto-detected from its name — see
//  `CourseLevel.detect` — since that's how Rutgers Prep labels it right in
//  the course title ("AP ...", "Honors ...").
//
//  The one thing this can't automate is your actual grade in a class — that
//  lives in Rutgers Prep's own gradebook, which this app has no access to.
//  Picking your current letter grade per class is the only input left.
//

import Foundation

nonisolated enum RutgersPrepGPA {
    /// Standard unweighted 4.0 scale.
    private static let scale: [(label: String, points: Double)] = [
        ("A", 4.0), ("A-", 3.67),
        ("B+", 3.33), ("B", 3.0), ("B-", 2.67),
        ("C+", 2.33), ("C", 2.0), ("C-", 1.67),
        ("D+", 1.33), ("D", 1.0), ("D-", 0.67),
        ("F", 0.0),
    ]

    static var labels: [String] { scale.map(\.label) }

    static func basePoints(for label: String) -> Double? {
        scale.first { $0.label == label }?.points
    }

    static func points(for label: String, level: CourseLevel, weighted: Bool) -> Double? {
        guard let base = basePoints(for: label) else { return nil }
        return base + (weighted ? level.gpaBump : 0)
    }
}

extension CourseLevel {
    /// Rutgers Prep's official GPA weighting bump, added to a course's base
    /// grade points when calculating weighted GPA.
    var gpaBump: Double {
        switch self {
        case .regular: return 0
        case .honors: return 1.0 / 3.0
        case .ap: return 2.0 / 3.0
        }
    }
}

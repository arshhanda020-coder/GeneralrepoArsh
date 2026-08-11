//
//  RutgersPrepGPA.swift
//  Odysseus
//
//  Rutgers Prep's official GPA policy, so the GPA Calculator needs zero
//  manual setup — no building a grading scale by hand, no flagging Honors/AP
//  per class. The full grade table below (unweighted 4.0 scale, plus the
//  Honors and AP/P-AP columns) is Rutgers Prep's actual published table:
//  Honors gets a one-third GPA bump, AP/P-AP gets a two-thirds bump. Each
//  class's level is auto-detected from its name — see `CourseLevel.detect`
//  — since that's how Rutgers Prep labels it right in the course title
//  ("AP ...", "Honors ...").
//
//  The one thing this can't automate is your actual grade in a class — that
//  lives in Rutgers Prep's own gradebook, which this app has no access to.
//  Picking your current letter grade per class is the only input left.
//

import Foundation

nonisolated enum RutgersPrepGPA {
    private struct Row {
        let label: String
        let percentRange: String
        let regular: Double
        let honors: Double
        let ap: Double
    }

    /// Rutgers Prep's official grade table.
    private static let table: [Row] = [
        Row(label: "A+", percentRange: "97–100", regular: 4.333, honors: 4.666, ap: 5.0),
        Row(label: "A", percentRange: "93–96", regular: 4.0, honors: 4.333, ap: 4.667),
        Row(label: "A-", percentRange: "90–92", regular: 3.667, honors: 4.0, ap: 4.334),
        Row(label: "B+", percentRange: "87–89", regular: 3.333, honors: 3.666, ap: 4.0),
        Row(label: "B", percentRange: "83–86", regular: 3.0, honors: 3.333, ap: 3.667),
        Row(label: "B-", percentRange: "80–82", regular: 2.667, honors: 3.0, ap: 3.334),
        Row(label: "C+", percentRange: "77–79", regular: 2.333, honors: 2.666, ap: 3.0),
        Row(label: "C", percentRange: "73–76", regular: 2.0, honors: 2.333, ap: 2.667),
        Row(label: "C-", percentRange: "70–72", regular: 1.667, honors: 2.0, ap: 2.334),
        Row(label: "D+", percentRange: "67–69", regular: 1.333, honors: 1.666, ap: 2.0),
        Row(label: "D", percentRange: "63–66", regular: 1.0, honors: 1.333, ap: 1.667),
        Row(label: "D-", percentRange: "60–62", regular: 0.667, honors: 1.0, ap: 1.334),
        Row(label: "F", percentRange: "0–59", regular: 0.0, honors: 0.0, ap: 0.0),
    ]

    static var labels: [String] { table.map(\.label) }

    static func percentRange(for label: String) -> String? {
        table.first { $0.label == label }?.percentRange
    }

    static func points(for label: String, level: CourseLevel, weighted: Bool) -> Double? {
        guard let row = table.first(where: { $0.label == label }) else { return nil }
        guard weighted else { return row.regular }
        switch level {
        case .regular: return row.regular
        case .honors: return row.honors
        case .ap: return row.ap
        }
    }
}

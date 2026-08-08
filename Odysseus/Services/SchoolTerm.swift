//
//  SchoolTerm.swift
//  Odysseus
//
//  Fall/Spring split, derived automatically from a date rather than typed in
//  per item — consistent with the rest of School being automatic. Jan-Jun is
//  Spring, Jul-Dec is Fall; Summer Work sits outside both on purpose (see
//  Topic.isSummerWork) so it's never pulled into either semester's numbers.
//

import Foundation

enum SchoolTerm: String, CaseIterable, Identifiable {
    case fall, spring, fullYear

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fall: return "Fall"
        case .spring: return "Spring"
        case .fullYear: return "Full Year"
        }
    }

    /// Fall = Jul-Dec, Spring = Jan-Jun.
    static func term(for date: Date) -> SchoolTerm {
        let month = Calendar.current.component(.month, from: date)
        return month <= 6 ? .spring : .fall
    }

    /// Whether a date falls in this term — .fullYear matches everything.
    func matches(_ date: Date) -> Bool {
        self == .fullYear || Self.term(for: date) == self
    }
}

/// Shared across every School screen (GPA Calculator, class detail, topic
/// detail) so picking a semester in one place scopes them all consistently.
nonisolated enum SchoolTermSettings {
    private static let key = "school_selected_term"

    static var selected: SchoolTerm {
        get { UserDefaults.standard.string(forKey: key).flatMap(SchoolTerm.init) ?? .fullYear }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: key) }
    }
}

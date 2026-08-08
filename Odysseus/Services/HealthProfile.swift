//
//  HealthProfile.swift
//  Odysseus
//

import Foundation

nonisolated enum HealthProfile {
    private static let heightKey = "health_profile_height_inches"
    private static let ageKey = "health_profile_age"
    private static let sexKey = "health_profile_sex"
    private static let activityLevelKey = "health_profile_activity_level"

    static var heightInches: Double? {
        get { UserDefaults.standard.object(forKey: heightKey) as? Double }
        set { UserDefaults.standard.set(newValue, forKey: heightKey) }
    }

    static var age: Int? {
        get { UserDefaults.standard.object(forKey: ageKey) as? Int }
        set { UserDefaults.standard.set(newValue, forKey: ageKey) }
    }

    /// Free-text on purpose (e.g. "male", "female", "prefer not to say") — only
    /// used as a rough factor in AI calorie-burn estimates, not stored as an enum.
    static var sex: String? {
        get { UserDefaults.standard.string(forKey: sexKey) }
        set { UserDefaults.standard.set(newValue, forKey: sexKey) }
    }

    /// One of ActivityLevel's rawValues — baseline activity factor for the
    /// maintenance-calorie estimate, separate from logged workouts (which get
    /// added on top as extra burn).
    static var activityLevel: String? {
        get { UserDefaults.standard.string(forKey: activityLevelKey) }
        set { UserDefaults.standard.set(newValue, forKey: activityLevelKey) }
    }
}

enum ActivityLevel: String, CaseIterable, Identifiable {
    case sedentary = "Sedentary"
    case lightlyActive = "Lightly Active"
    case moderatelyActive = "Moderately Active"
    case veryActive = "Very Active"

    var id: String { rawValue }

    var multiplier: Double {
        switch self {
        case .sedentary: return 1.2
        case .lightlyActive: return 1.375
        case .moderatelyActive: return 1.55
        case .veryActive: return 1.725
        }
    }
}

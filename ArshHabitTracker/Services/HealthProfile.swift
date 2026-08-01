//
//  HealthProfile.swift
//  ArshHabitTracker
//

import Foundation

nonisolated enum HealthProfile {
    private static let heightKey = "health_profile_height_inches"
    private static let ageKey = "health_profile_age"

    static var heightInches: Double? {
        get { UserDefaults.standard.object(forKey: heightKey) as? Double }
        set { UserDefaults.standard.set(newValue, forKey: heightKey) }
    }

    static var age: Int? {
        get { UserDefaults.standard.object(forKey: ageKey) as? Int }
        set { UserDefaults.standard.set(newValue, forKey: ageKey) }
    }
}

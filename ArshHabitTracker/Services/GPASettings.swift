//
//  GPASettings.swift
//  ArshHabitTracker
//

import Foundation

nonisolated enum GPASettings {
    private static let bonusKey = "gpa_honors_bonus"

    /// Added on top of a grade's scale points for courses marked Honors/AP.
    static var honorsBonus: Double {
        get { (UserDefaults.standard.object(forKey: bonusKey) as? Double) ?? 1.0 }
        set { UserDefaults.standard.set(newValue, forKey: bonusKey) }
    }
}

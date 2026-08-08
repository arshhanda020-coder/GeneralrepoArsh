//
//  CalorieMath.swift
//  Odysseus
//
//  Mifflin-St Jeor BMR → TDEE (maintenance calories), the standard formula
//  used by most fitness trackers. Logged workouts are treated as burn on
//  top of the activity-level baseline, not folded into it — same "eat back
//  your exercise calories" model MyFitnessPal-style apps use.
//

import Foundation

enum CalorieMath {
    struct Result {
        let maintenanceCalories: Int
        let exerciseCalories: Int
        let totalBurn: Int
        let caloriesEaten: Int
        /// Positive = surplus, negative = deficit.
        let net: Int
    }

    /// nil when there isn't enough profile data (weight/height/age) to compute a real BMR.
    static func todaysOverview(weight: Double?, foodCalories: Int, exerciseCalories: Int) -> Result? {
        guard let weight, let heightInches = HealthProfile.heightInches, let age = HealthProfile.age else { return nil }
        let weightKg = weight * 0.453592
        let heightCm = heightInches * 2.54
        let sexAdjustment: Double
        switch HealthProfile.sex {
        case "Male": sexAdjustment = 5
        case "Female": sexAdjustment = -161
        default: sexAdjustment = -78 // midpoint between the male/female constants
        }
        let bmr = (10 * weightKg) + (6.25 * heightCm) - (5 * Double(age)) + sexAdjustment
        let activityLevel = ActivityLevel(rawValue: HealthProfile.activityLevel ?? "") ?? .lightlyActive
        let maintenance = Int(bmr * activityLevel.multiplier)
        let totalBurn = maintenance + exerciseCalories
        return Result(
            maintenanceCalories: maintenance,
            exerciseCalories: exerciseCalories,
            totalBurn: totalBurn,
            caloriesEaten: foodCalories,
            net: foodCalories - totalBurn
        )
    }
}

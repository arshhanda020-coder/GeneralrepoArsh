//
//  NutritionGoals.swift
//  Odysseus
//
//  Daily calorie + macro targets for the Food tab's ring dashboard — the
//  same "goal" concept Cal AI/MyFitnessPal are built around. Manual values
//  win when set; otherwise everything derives from CalorieMath's maintenance
//  estimate (needs weight/height/age/sex from HealthProfile) adjusted by
//  goalMode, then split into macro grams by a standard ratio.
//

import Foundation

nonisolated enum NutritionGoals {
    private static let calorieKey = "nutrition_goal_calories"
    private static let proteinKey = "nutrition_goal_protein_g"
    private static let carbsKey = "nutrition_goal_carbs_g"
    private static let fatKey = "nutrition_goal_fat_g"
    private static let modeKey = "nutrition_goal_mode"

    /// Manually-set daily calorie goal, if any. Falls back to a maintenance-based estimate.
    static var manualCalories: Int? {
        get { UserDefaults.standard.object(forKey: calorieKey) as? Int }
        set { UserDefaults.standard.set(newValue, forKey: calorieKey) }
    }

    static var manualProteinGrams: Double? {
        get { UserDefaults.standard.object(forKey: proteinKey) as? Double }
        set { UserDefaults.standard.set(newValue, forKey: proteinKey) }
    }

    static var manualCarbsGrams: Double? {
        get { UserDefaults.standard.object(forKey: carbsKey) as? Double }
        set { UserDefaults.standard.set(newValue, forKey: carbsKey) }
    }

    static var manualFatGrams: Double? {
        get { UserDefaults.standard.object(forKey: fatKey) as? Double }
        set { UserDefaults.standard.set(newValue, forKey: fatKey) }
    }

    static var mode: GoalMode {
        get { GoalMode(rawValue: UserDefaults.standard.string(forKey: modeKey) ?? "") ?? .maintain }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: modeKey) }
    }

    /// Effective daily calorie goal — manual override, else maintenance ± the
    /// goalMode's offset, else a generic 2000 fallback when there's no
    /// profile data yet at all (so the ring never has nothing to show).
    static func calorieGoal(maintenanceCalories: Int?) -> Int {
        if let manualCalories { return manualCalories }
        if let maintenanceCalories { return maintenanceCalories + mode.calorieOffset }
        return 2000
    }

    /// Effective macro gram goals — manual overrides win per-macro; anything
    /// left unset is derived from the calorie goal via a standard 30/40/30
    /// protein/carb/fat split (4/4/9 kcal per gram).
    static func macroGoals(calorieGoal: Int) -> (protein: Double, carbs: Double, fat: Double) {
        let defaultProtein = Double(calorieGoal) * 0.30 / 4
        let defaultCarbs = Double(calorieGoal) * 0.40 / 4
        let defaultFat = Double(calorieGoal) * 0.30 / 9
        return (
            manualProteinGrams ?? defaultProtein,
            manualCarbsGrams ?? defaultCarbs,
            manualFatGrams ?? defaultFat
        )
    }
}

enum GoalMode: String, CaseIterable, Identifiable {
    case lose = "Lose Weight"
    case maintain = "Maintain"
    case gain = "Gain Weight"

    var id: String { rawValue }

    /// Standard ~500 cal/day deficit or surplus — roughly 1lb/week.
    var calorieOffset: Int {
        switch self {
        case .lose: return -500
        case .maintain: return 0
        case .gain: return 500
        }
    }
}

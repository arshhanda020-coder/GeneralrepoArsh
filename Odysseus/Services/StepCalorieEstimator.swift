//
//  StepCalorieEstimator.swift
//  Odysseus
//
//  Turns today's Apple Health step count into a calorie-burn number, the
//  same "MyFitnessPal synced with Apple Health" behavior: steps count as
//  exercise burn added back on top of the (already-sedentary-assumed) daily
//  calorie goal, not folded into the goal itself.
//

import Foundation

nonisolated enum StepCalorieEstimator {
    /// ~0.0005 kcal per step per kg of body weight — roughly the commonly
    /// cited ~0.04 kcal/step for an average ~80kg adult, scaled by weight.
    private static let caloriesPerStepPerKg = 0.0005

    /// Falls back to an average ~160lb adult if there's no weight on file yet,
    /// so steps still count toward burn even before Progress-tab data exists.
    static func calories(steps: Int, weightLbs: Double?) -> Int {
        guard steps > 0 else { return 0 }
        let weightKg = (weightLbs ?? 160) * 0.453592
        return Int(Double(steps) * caloriesPerStepPerKg * weightKg)
    }
}

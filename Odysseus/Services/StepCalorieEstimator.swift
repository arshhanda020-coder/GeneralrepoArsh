//
//  StepCalorieEstimator.swift
//  Odysseus
//
//  Turns today's Apple Health step count into a calorie-burn number, the
//  same "MyFitnessPal synced with Apple Health" behavior: steps count as
//  exercise burn added back on top of the (already-sedentary-assumed) daily
//  calorie goal, not folded into the goal itself.
//
//  Calorie math here goes through AI first — same pattern as workout calorie
//  estimation (LogWorkoutSheet) — using the person's actual body stats
//  instead of one fixed kcal/step constant, falling back to the local
//  formula only if AI is unavailable/fails.
//

import Foundation

nonisolated enum StepCalorieEstimator {
    /// ~0.0005 kcal per step per kg of body weight — roughly the commonly
    /// cited ~0.04 kcal/step for an average ~80kg adult, scaled by weight.
    private static let caloriesPerStepPerKg = 0.0005

    /// Falls back to an average ~160lb adult if there's no weight on file yet,
    /// so steps still count toward burn even before Progress-tab data exists.
    /// This is the synchronous local formula — used as the AI fallback, and
    /// as an instant placeholder while `estimateWithAI` is in flight.
    static func calories(steps: Int, weightLbs: Double?) -> Int {
        guard steps > 0 else { return 0 }
        let weightKg = (weightLbs ?? 160) * 0.453592
        return Int(Double(steps) * caloriesPerStepPerKg * weightKg)
    }

    /// AI estimate of calories burned from today's steps, using whatever
    /// body stats are on file. Falls back to the local formula (silently,
    /// never leaving the burn number blank) if AI is unavailable or fails
    /// to parse — mirrors LogWorkoutSheet's workout-calorie flow.
    static func estimateWithAI(
        steps: Int,
        weightLbs: Double?,
        heightInches: Double?,
        age: Int?,
        sex: String?
    ) async -> (calories: Int, isEstimateFallback: Bool) {
        guard steps > 0 else { return (0, false) }
        let fallback = calories(steps: steps, weightLbs: weightLbs)

        var statsLines: [String] = []
        if let weightLbs { statsLines.append("Body weight: \(Int(weightLbs)) lbs") }
        if let heightInches { statsLines.append("Height: \(Int(heightInches)) in") }
        if let age { statsLines.append("Age: \(age)") }
        if let sex, sex != "Prefer not to say" { statsLines.append("Sex: \(sex)") }
        let statsBlock = statsLines.isEmpty ? "No body stats on file — use reasonable average adult assumptions." : statsLines.joined(separator: "\n")

        let prompt = """
        Estimate calories burned from walking today, given this step count. Respond in EXACTLY this format, nothing else:
        CALORIES: <number only>

        Person's stats:
        \(statsBlock)

        Steps today: \(steps)
        """

        do {
            let response = try await AISettings.currentService.askAboutImage(
                prompt: prompt,
                imageData: nil,
                systemPrompt: "You are a fitness/exercise physiology estimator. Give your best reasonable estimate of calories burned from walking given the person's stats and step count — approximate is fine, always provide a number."
            )
            guard let range = response.range(of: "CALORIES:", options: .caseInsensitive) else { return (fallback, true) }
            let digits = response[range.upperBound...].filter { $0.isNumber }
            guard let parsed = Int(digits) else { return (fallback, true) }
            return (parsed, false)
        } catch {
            return (fallback, true)
        }
    }
}

//
//  NutritionRingsView.swift
//  Odysseus
//
//  The Cal AI / MyFitnessPal signature dashboard — one big "calories
//  remaining" ring plus three small macro rings underneath — reskinned in
//  Odysseus's glass-panel HUD material instead of a flat rounded card.
//  Same equation MyFitnessPal uses: Remaining = Goal - Food + Exercise.
//

import SwiftUI

struct NutritionRingsView: View {
    let calorieGoal: Int
    let caloriesEaten: Int
    let exerciseCalories: Int

    let proteinGoal: Double
    let proteinEaten: Double
    let carbsGoal: Double
    let carbsEaten: Double
    let fatGoal: Double
    let fatEaten: Double

    private var remaining: Int { calorieGoal - caloriesEaten + exerciseCalories }
    private var isOverBudget: Bool { remaining < 0 }
    private var calorieProgress: Double {
        guard calorieGoal > 0 else { return 0 }
        return min(Double(caloriesEaten) / Double(calorieGoal), 1)
    }
    private var ringColor: Color { isOverBudget ? Theme.terminalAmber : MindMapSection.health.accentColor }

    var body: some View {
        VStack(spacing: 16) {
            HStack(alignment: .center, spacing: 20) {
                bigRing
                VStack(alignment: .leading, spacing: 7) {
                    equationRow("Goal", calorieGoal)
                    equationRow("Food", caloriesEaten, sign: "+")
                    if exerciseCalories > 0 {
                        equationRow("Exercise", exerciseCalories, sign: "+")
                    }
                    Divider().overlay(Theme.cardBorder)
                    HStack(spacing: 4) {
                        Text(isOverBudget ? "Over" : "Remaining")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Theme.dimText)
                        Spacer()
                        Text("\(abs(remaining))")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(ringColor)
                    }
                }
            }

            HStack(spacing: 10) {
                macroRing(label: "PROTEIN", eaten: proteinEaten, goal: proteinGoal, color: Theme.accent)
                macroRing(label: "CARBS", eaten: carbsEaten, goal: carbsGoal, color: Theme.terminalAmber)
                macroRing(label: "FAT", eaten: fatEaten, goal: fatGoal, color: Theme.reactorGlow)
            }
        }
        .padding(14)
        .glassPanel(cornerRadius: 14, glow: MindMapSection.health.accentColor.opacity(0.35))
    }

    private var bigRing: some View {
        ZStack {
            Circle()
                .stroke(Theme.cardBorder.opacity(0.5), lineWidth: 12)
            Circle()
                .trim(from: 0, to: calorieProgress)
                .stroke(ringColor, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.4), value: calorieProgress)
            VStack(spacing: 1) {
                Text("\(abs(remaining))")
                    .font(.system(.title2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .contentTransition(.numericText())
                Text(isOverBudget ? "OVER" : "LEFT")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
            }
        }
        .frame(width: 110, height: 110)
    }

    private func equationRow(_ label: String, _ value: Int, sign: String = "") -> some View {
        HStack {
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
            Spacer()
            Text("\(sign)\(value)")
                .font(.caption.monospacedDigit())
                .foregroundStyle(Theme.primaryText)
        }
    }

    private func macroRing(label: String, eaten: Double, goal: Double, color: Color) -> some View {
        let progress = goal > 0 ? min(eaten / goal, 1) : 0
        let remainingGrams = max(goal - eaten, 0)
        return VStack(spacing: 6) {
            ZStack {
                Circle()
                    .stroke(Theme.cardBorder.opacity(0.5), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(color, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.4), value: progress)
                Text("\(Int(remainingGrams))g")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.primaryText)
                    .minimumScaleFactor(0.7)
            }
            .frame(width: 56, height: 56)
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .tracking(0.3)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    NutritionRingsView(
        calorieGoal: 2200, caloriesEaten: 1450, exerciseCalories: 220,
        proteinGoal: 160, proteinEaten: 92,
        carbsGoal: 220, carbsEaten: 140,
        fatGoal: 73, fatEaten: 40
    )
    .padding()
    .background(Theme.background)
}

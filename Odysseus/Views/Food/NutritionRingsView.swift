//
//  NutritionRingsView.swift
//  Odysseus
//
//  MyFitnessPal's exact Diary summary, reskinned in Odysseus's glass-panel
//  HUD material instead of MFP's flat white card: the "calories remaining"
//  ring worked from MFP's own equation (Remaining = Goal - Food + Exercise),
//  an explicit Consumed/Burned stat row so those two numbers are never
//  buried in the equation, and macros as MFP-style horizontal bars (MFP
//  doesn't use circles for macros — that's a Cal AI-ism) instead of rings.
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
        VStack(spacing: 14) {
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
                statTile(label: "CONSUMED", value: caloriesEaten, icon: "fork.knife", color: MindMapSection.health.accentColor)
                statTile(label: "BURNED", value: exerciseCalories, icon: "flame.fill", color: Theme.terminalAmber)
            }

            VStack(spacing: 10) {
                macroBar(label: "PROTEIN", eaten: proteinEaten, goal: proteinGoal, color: Theme.accent)
                macroBar(label: "CARBS", eaten: carbsEaten, goal: carbsGoal, color: Theme.terminalAmber)
                macroBar(label: "FAT", eaten: fatEaten, goal: fatGoal, color: Theme.reactorGlow)
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

    /// Explicit "Calories Consumed" / "Calories Burned" tiles — MFP folds
    /// these into its Goal/Food/Exercise equation, but callers asked for
    /// them called out as their own readable numbers, not buried in the sum.
    private func statTile(label: String, value: Int, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(color)
                Text(label)
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.3)
                    .foregroundStyle(Theme.dimText)
            }
            Text("\(value)")
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundStyle(Theme.primaryText)
            Text("cal")
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .glassPanel(cornerRadius: 10)
    }

    /// MFP-style horizontal macro progress bar (MFP's Nutrition tab uses
    /// bars, not the circular macro rings Cal AI popularized).
    private func macroBar(label: String, eaten: Double, goal: Double, color: Color) -> some View {
        let progress = goal > 0 ? min(eaten / goal, 1) : 0
        return VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.3)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Text("\(Int(eaten))g / \(Int(goal))g")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.primaryText)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.cardBorder.opacity(0.4))
                    Capsule().fill(color)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 6)
        }
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

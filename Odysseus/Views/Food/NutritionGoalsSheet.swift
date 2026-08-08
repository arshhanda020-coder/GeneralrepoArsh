//
//  NutritionGoalsSheet.swift
//  Odysseus
//
//  Edit the daily calorie + macro targets the ring dashboard tracks against
//  — Cal AI/MyFitnessPal both let you override their auto-calculated goal
//  the same way. Leaving a field blank falls back to the computed default.
//
//  Also has an AI advisor: not automatic — the cut (1800 cal / 160g protein)
//  stays fixed until the user picks it, but they can ask AI whether their
//  weight trend suggests it's time to switch to Maintain or Gain.
//

import SwiftUI
import SwiftData

struct NutritionGoalsSheet: View {
    let maintenanceCalories: Int?

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProgressEntry.date, order: .reverse) private var progressEntries: [ProgressEntry]
    @State private var mode: GoalMode = NutritionGoals.mode
    @State private var calorieText: String = NutritionGoals.manualCalories.map(String.init) ?? ""
    @State private var proteinText: String = NutritionGoals.manualProteinGrams.map { String(format: "%.0f", $0) } ?? ""
    @State private var carbsText: String = NutritionGoals.manualCarbsGrams.map { String(format: "%.0f", $0) } ?? ""
    @State private var fatText: String = NutritionGoals.manualFatGrams.map { String(format: "%.0f", $0) } ?? ""
    @State private var isAskingAI = false
    @State private var aiAdvice: String?
    @State private var aiError: String?

    private var computedCalorieGoal: Int { NutritionGoals.calorieGoal(maintenanceCalories: maintenanceCalories) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Goal", selection: $mode) {
                        ForEach(GoalMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                } footer: {
                    if maintenanceCalories != nil {
                        Text("Applied on top of your maintenance calories (from Progress tab weight/height/age).")
                    } else {
                        Text("Add weight, height, age, and sex in the Progress tab for an accurate maintenance estimate — using 2000 cal as a generic baseline until then.")
                    }
                }

                Section("Daily Calories") {
                    HStack {
                        Text("Goal")
                        Spacer()
                        TextField("\(computedCalorieGoal)", text: $calorieText)
                            .platformKeyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 90)
                    }
                    if !calorieText.isEmpty {
                        Button("Reset to computed") { calorieText = "" }
                    }
                }

                Section("Daily Macros (grams)") {
                    macroField("Protein", text: $proteinText)
                    macroField("Carbs", text: $carbsText)
                    macroField("Fat", text: $fatText)
                    if !proteinText.isEmpty || !carbsText.isEmpty || !fatText.isEmpty {
                        Button("Reset to computed") {
                            proteinText = ""
                            carbsText = ""
                            fatText = ""
                        }
                    }
                }

                Section {
                    Button {
                        askAI()
                    } label: {
                        Label(isAskingAI ? "Thinking…" : "Ask AI: is it time to switch?", systemImage: "sparkles")
                    }
                    .disabled(isAskingAI)

                    if let aiAdvice {
                        Text(aiAdvice)
                            .font(.callout)
                            .foregroundStyle(Theme.primaryText)
                    }
                    if let aiError {
                        Text(aiError).font(.caption).foregroundStyle(Theme.negative)
                    }
                } footer: {
                    Text("Looks at your recent weight trend against the current goal and suggests Lose/Maintain/Gain — doesn't change anything on its own, flip the picker above yourself if you agree.")
                }
            }
            .navigationTitle("Nutrition Goals")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func macroField(_ label: String, text: Binding<String>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .platformKeyboardType(.numberPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 90)
            Text("g").foregroundStyle(Theme.dimText)
        }
    }

    private func askAI() {
        isAskingAI = true
        aiError = nil
        aiAdvice = nil

        let recentWeights = progressEntries
            .compactMap { entry -> String? in
                guard let weight = entry.weight else { return nil }
                return "\(entry.date.formatted(.dateTime.month(.abbreviated).day())): \(Int(weight)) lbs"
            }
            .prefix(10)
            .joined(separator: "\n")
        let weightBlock = recentWeights.isEmpty ? "No weigh-ins logged yet in the Progress tab." : recentWeights

        let currentCalories = Int(calorieText) ?? computedCalorieGoal
        let currentProtein = proteinText.isEmpty ? NutritionGoals.macroGoals(calorieGoal: currentCalories).protein : (Double(proteinText) ?? 0)

        let prompt = """
        Someone is tracking calories with a fixed daily goal. Based on their recent weight trend, tell them plainly whether they should stay on their current goal, or switch to Maintain or Gain. Respond in EXACTLY this format, nothing else:
        RECOMMENDATION: <Stay on current goal | Switch to Maintain | Switch to Gain>
        WHY: <1-2 short sentences, plain language, referencing the actual trend>

        Current goal mode: \(mode.rawValue)
        Current daily calorie target: \(currentCalories) cal
        Current daily protein target: \(Int(currentProtein))g

        Recent weigh-ins (most recent first):
        \(weightBlock)
        """

        Task {
            do {
                let response = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: nil,
                    systemPrompt: "You are a plainspoken nutrition coach. Be direct and concise — this is a quick check-in, not a lecture. If there isn't enough weight data yet, say so and suggest logging a few more weigh-ins before deciding."
                )
                aiAdvice = response.trimmingCharacters(in: .whitespacesAndNewlines)
            } catch {
                aiError = error.localizedDescription
            }
            isAskingAI = false
        }
    }

    private func save() {
        NutritionGoals.mode = mode
        NutritionGoals.manualCalories = Int(calorieText)
        NutritionGoals.manualProteinGrams = Double(proteinText)
        NutritionGoals.manualCarbsGrams = Double(carbsText)
        NutritionGoals.manualFatGrams = Double(fatText)
    }
}

#Preview {
    NutritionGoalsSheet(maintenanceCalories: 2200)
}

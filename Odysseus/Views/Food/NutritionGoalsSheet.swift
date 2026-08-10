//
//  NutritionGoalsSheet.swift
//  Odysseus
//
//  Edit the daily calorie + macro targets the ring dashboard tracks against
//  — Cal AI/MyFitnessPal both let you override their auto-calculated goal
//  the same way. Leaving a field blank falls back to the computed default.
//

import SwiftUI

struct NutritionGoalsSheet: View {
    let maintenanceCalories: Int?

    @Environment(\.dismiss) private var dismiss
    @State private var mode: GoalMode = NutritionGoals.mode
    @State private var calorieText: String = NutritionGoals.manualCalories.map(String.init) ?? ""
    @State private var proteinText: String = NutritionGoals.manualProteinGrams.map { String(format: "%.0f", $0) } ?? ""
    @State private var carbsText: String = NutritionGoals.manualCarbsGrams.map { String(format: "%.0f", $0) } ?? ""
    @State private var fatText: String = NutritionGoals.manualFatGrams.map { String(format: "%.0f", $0) } ?? ""

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

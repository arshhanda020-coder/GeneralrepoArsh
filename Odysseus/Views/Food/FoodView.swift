//
//  FoodView.swift
//  Odysseus
//
//  Food sub-tab within Health — no own nav title/toolbar since it's embedded
//  in HealthView's segmented picker. Cal AI/MyFitnessPal-style layout: a
//  calorie + macro ring dashboard up top, then a diary grouped into
//  Breakfast/Lunch/Dinner/Snacks sections, each loggable independently.
//

import SwiftUI
import SwiftData

struct FoodContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query(sort: \ProgressEntry.date, order: .reverse) private var progressEntries: [ProgressEntry]
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var workoutEntries: [WorkoutEntry]

    @State private var showingLog = false
    @State private var showingGoals = false
    @State private var logMealType: MealType = .snack
    @State private var editingEntry: FoodEntry?

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var todaysEntries: [FoodEntry] { allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) } }
    private var historyEntries: [FoodEntry] { allEntries.filter { !Calendar.current.isDate($0.date, inSameDayAs: today) } }

    private var todaysTotals: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        let cals = todaysEntries.compactMap { $0.calories }.reduce(0, +)
        let protein = todaysEntries.compactMap { $0.proteinGrams }.reduce(0, +)
        let carbs = todaysEntries.compactMap { $0.carbsGrams }.reduce(0, +)
        let fat = todaysEntries.compactMap { $0.fatGrams }.reduce(0, +)
        return (cals, protein, carbs, fat)
    }

    private var todaysExerciseCalories: Int {
        workoutEntries
            .filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
            .compactMap(\.caloriesBurned)
            .reduce(0, +)
    }

    private var maintenanceCalories: Int? {
        let weight = progressEntries.first(where: { $0.weight != nil })?.weight
        return CalorieMath.todaysOverview(weight: weight, foodCalories: 0, exerciseCalories: 0)?.maintenanceCalories
    }

    private var calorieGoal: Int { NutritionGoals.calorieGoal(maintenanceCalories: maintenanceCalories) }
    private var macroGoals: (protein: Double, carbs: Double, fat: Double) { NutritionGoals.macroGoals(calorieGoal: calorieGoal) }

    /// Consecutive days (ending today or yesterday) with at least one entry logged.
    private var streak: Int {
        let loggedDays = Set(allEntries.map { Calendar.current.startOfDay(for: $0.date) })
        guard !loggedDays.isEmpty else { return 0 }
        var count = 0
        var cursor = today
        if !loggedDays.contains(cursor) {
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
            guard loggedDays.contains(cursor) else { return 0 }
        }
        while loggedDays.contains(cursor) {
            count += 1
            cursor = Calendar.current.date(byAdding: .day, value: -1, to: cursor) ?? cursor
        }
        return count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            NutritionRingsView(
                calorieGoal: calorieGoal,
                caloriesEaten: todaysTotals.calories,
                exerciseCalories: todaysExerciseCalories,
                proteinGoal: macroGoals.protein,
                proteinEaten: todaysTotals.protein,
                carbsGoal: macroGoals.carbs,
                carbsEaten: todaysTotals.carbs,
                fatGoal: macroGoals.fat,
                fatEaten: todaysTotals.fat
            )

            ForEach(MealType.allCases) { meal in
                mealSection(meal)
            }

            if !historyEntries.isEmpty {
                historySection
            }
        }
        .sheet(isPresented: $showingLog) {
            LogFoodSheet(entry: nil, defaultMealType: logMealType)
        }
        .sheet(item: $editingEntry) { entry in
            LogFoodSheet(entry: entry, defaultMealType: entry.mealType)
        }
        .sheet(isPresented: $showingGoals) {
            NutritionGoalsSheet(maintenanceCalories: maintenanceCalories)
        }
    }

    private var header: some View {
        HStack {
            Text("NUTRITION")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            if streak > 0 {
                HStack(spacing: 3) {
                    Image(systemName: "flame.fill")
                        .font(.caption2)
                    Text("\(streak)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                }
                .foregroundStyle(Theme.terminalAmber)
            }
            Spacer()
            Button {
                showingGoals = true
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
        }
    }

    private func mealSection(_ meal: MealType) -> some View {
        let entries = todaysEntries.filter { $0.mealType == meal }
        let subtotal = entries.compactMap(\.calories).reduce(0, +)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: meal.symbolName)
                    .font(.caption)
                    .foregroundStyle(MindMapSection.health.accentColor)
                Text(meal.rawValue.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                if subtotal > 0 {
                    Text("· \(subtotal) cal")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                Button {
                    logMealType = meal
                    showingLog = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MindMapSection.health.accentColor)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                if entries.isEmpty {
                    Text("Nothing logged yet.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                        .padding(10)
                } else {
                    ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().overlay(Theme.cardBorder)
                        }
                        entryRow(entry)
                    }
                }
            }
            .glassPanel(cornerRadius: 10)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HISTORY")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(spacing: 0) {
                ForEach(Array(historyEntries.prefix(30).enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Divider().overlay(Theme.cardBorder)
                    }
                    entryRow(entry)
                }
            }
            .glassPanel(cornerRadius: 10)
        }
    }

    private func entryRow(_ entry: FoodEntry) -> some View {
        HStack(spacing: 10) {
            if let imageData = entry.imageData, let uiImage = PlatformImage(data: imageData) {
                Image(platformImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: entry.mealType.symbolName)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                    .frame(width: 40, height: 40)
                    .background(Theme.card.opacity(0.4))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.note)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let cal = entry.calories {
                        Text("\(cal) cal")
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                    if entry.proteinGrams != nil || entry.carbsGrams != nil || entry.fatGrams != nil {
                        Text(macroLabel(entry))
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.dimText)
                    }
                }
            }
            Spacer()
            Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.dimText)
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { editingEntry = entry }
    }

    private func macroLabel(_ entry: FoodEntry) -> String {
        let p = entry.proteinGrams.map { String(format: "%.0fP", $0) }
        let c = entry.carbsGrams.map { String(format: "%.0fC", $0) }
        let f = entry.fatGrams.map { String(format: "%.0fF", $0) }
        return [p, c, f].compactMap { $0 }.joined(separator: " · ")
    }
}

#Preview {
    NavigationStack {
        FoodContentView()
    }
    .modelContainer(for: [FoodEntry.self, WorkoutEntry.self, ProgressEntry.self], inMemory: true)
}

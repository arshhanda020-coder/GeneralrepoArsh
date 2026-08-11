//
//  FoodView.swift
//  Odysseus
//
//  Food sub-tab within Health — no own nav title/toolbar since it's embedded
//  in HealthView's segmented picker. Cal AI/MyFitnessPal-style layout: a
//  calorie + macro ring dashboard up top, then a single flat diary pool for
//  everything logged today (no Breakfast/Lunch/Dinner/Snacks split).
//

import SwiftUI
import SwiftData

struct FoodContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]
    @Query(sort: \ProgressEntry.date, order: .reverse) private var progressEntries: [ProgressEntry]
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var workoutEntries: [WorkoutEntry]
    @ObservedObject private var healthKit = HealthKitManager.shared

    @State private var showingLog = false
    @State private var showingGoals = false
    @State private var editingEntry: FoodEntry?
    @State private var showingLogWorkout = false
    @State private var editingWorkout: WorkoutEntry?

    /// AI's calorie-burn estimate for today's steps, once resolved — nil
    /// (falls back to the local formula) until `refreshStepCalories()`
    /// completes. Mirrors the workout flow's AI-first/formula-fallback shape.
    @State private var aiStepCalories: Int?
    @State private var isStepEstimateFallback = false

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var todaysEntries: [FoodEntry] { allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) } }
    private var historyEntries: [FoodEntry] { allEntries.filter { !Calendar.current.isDate($0.date, inSameDayAs: today) } }
    private var todaysWorkoutEntries: [WorkoutEntry] { workoutEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) } }

    private var todaysTotals: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        let cals = todaysEntries.compactMap { $0.calories }.reduce(0, +)
        let protein = todaysEntries.compactMap { $0.proteinGrams }.reduce(0, +)
        let carbs = todaysEntries.compactMap { $0.carbsGrams }.reduce(0, +)
        let fat = todaysEntries.compactMap { $0.fatGrams }.reduce(0, +)
        return (cals, protein, carbs, fat)
    }

    private var todaysWorkoutCalories: Int {
        todaysWorkoutEntries.compactMap(\.caloriesBurned).reduce(0, +)
    }

    /// Today's steps converted to a calorie burn, MFP's "synced with Apple
    /// Health" behavior — counted alongside logged workouts, not instead of.
    /// Prefers the AI estimate (`refreshStepCalories()`, using actual body
    /// stats) once it resolves; shows the instant local-formula number
    /// before then so the UI never sits blank.
    private var todaysStepCalories: Int {
        if let aiStepCalories { return aiStepCalories }
        guard let steps = healthKit.todaysSteps else { return 0 }
        let weight = progressEntries.first(where: { $0.weight != nil })?.weight
        return StepCalorieEstimator.calories(steps: steps, weightLbs: weight)
    }

    private var todaysExerciseCalories: Int { todaysWorkoutCalories + todaysStepCalories }

    /// Trailing 7 days (oldest to newest, including today) of consumed vs.
    /// burned — burned includes that day's logged workouts plus its Apple
    /// Health step count (from HealthKitManager's weekly bucket query, not
    /// just today's).
    private var weeklyBreakdown: [DayCalorieSummary] {
        let weight = progressEntries.first(where: { $0.weight != nil })?.weight
        return (0..<7).compactMap { offset -> DayCalorieSummary? in
            guard let day = Calendar.current.date(byAdding: .day, value: -6 + offset, to: today) else { return nil }
            let consumed = allEntries
                .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                .compactMap(\.calories)
                .reduce(0, +)
            let workoutBurn = workoutEntries
                .filter { Calendar.current.isDate($0.date, inSameDayAs: day) }
                .compactMap(\.caloriesBurned)
                .reduce(0, +)
            let stepBurn = StepCalorieEstimator.calories(steps: healthKit.weeklySteps[day] ?? 0, weightLbs: weight)
            return DayCalorieSummary(date: day, consumed: consumed, burned: workoutBurn + stepBurn)
        }
    }

    /// Most recent weigh-in minus the most recent weigh-in at or before 7
    /// days ago — nil (not zero) when there isn't enough data either side,
    /// so the UI can say "no data" instead of implying no change.
    private var weeklyWeightChange: Double? {
        guard let weekStart = Calendar.current.date(byAdding: .day, value: -6, to: today) else { return nil }
        let sorted = progressEntries.filter { $0.weight != nil }.sorted { $0.date < $1.date }
        guard sorted.count >= 2, let latest = sorted.last?.weight else { return nil }
        let baseline = sorted.last(where: { $0.date <= weekStart })?.weight ?? sorted.first?.weight
        guard let baseline else { return nil }
        return latest - baseline
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

            todaySection

            exerciseSection

            WeeklySummaryView(days: weeklyBreakdown, weightChangeLbs: weeklyWeightChange)

            if !historyEntries.isEmpty {
                historySection
            }
        }
        .task {
            await healthKit.refreshWeeklySteps()
        }
        .task(id: healthKit.todaysSteps) {
            await refreshStepCalories()
        }
        .sheet(isPresented: $showingLog) {
            LogFoodSheet(entry: nil)
        }
        .sheet(item: $editingEntry) { entry in
            LogFoodSheet(entry: entry)
        }
        .sheet(isPresented: $showingGoals) {
            NutritionGoalsSheet(maintenanceCalories: maintenanceCalories)
        }
        .sheet(isPresented: $showingLogWorkout) {
            LogWorkoutSheet(entry: nil)
        }
        .sheet(item: $editingWorkout) { entry in
            LogWorkoutSheet(entry: entry)
        }
        .onAppear {
            NutritionGoals.seedCutDefaultsIfNeeded()
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

    /// Everything logged today, flat — no Breakfast/Lunch/Dinner/Snacks split,
    /// just one pool you add to as you eat throughout the day.
    private var todaySection: some View {
        let subtotal = todaysEntries.compactMap(\.calories).reduce(0, +)
        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "fork.knife")
                    .font(.caption)
                    .foregroundStyle(MindMapSection.health.accentColor)
                Text("TODAY")
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
                    showingLog = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MindMapSection.health.accentColor)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                if todaysEntries.isEmpty {
                    Text("Nothing logged yet.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                        .padding(10)
                } else {
                    ForEach(Array(todaysEntries.enumerated()), id: \.element.id) { index, entry in
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

    private var exerciseSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.terminalAmber)
                Text("EXERCISE")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                if todaysExerciseCalories > 0 {
                    Text("· \(todaysExerciseCalories) cal burned")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                Button {
                    showingLogWorkout = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(Theme.terminalAmber)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                if todaysStepCalories == 0 && todaysWorkoutEntries.isEmpty {
                    Text("No exercise logged yet.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                        .padding(10)
                } else {
                    if todaysStepCalories > 0 {
                        stepsRow
                        if !todaysWorkoutEntries.isEmpty {
                            Divider().overlay(Theme.cardBorder)
                        }
                    }
                    ForEach(Array(todaysWorkoutEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().overlay(Theme.cardBorder)
                        }
                        workoutRow(entry)
                    }
                }
            }
            .glassPanel(cornerRadius: 10)
        }
    }

    /// A synthetic, non-tappable row for step-based burn — not a WorkoutEntry,
    /// just Apple Health's step count converted to calories, MFP's "synced
    /// with Apple Health" line.
    private var stepsRow: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.walk")
                .font(.caption)
                .foregroundStyle(MindMapSection.health.accentColor)
                .frame(width: 40, height: 40)
                .background(Theme.card.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            VStack(alignment: .leading, spacing: 1) {
                Text("Steps")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("\(healthKit.todaysSteps ?? 0) steps")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 1) {
                Text("-\(todaysStepCalories) cal")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.terminalAmber)
                if isStepEstimateFallback {
                    Text("(rough estimate)")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
            }
        }
        .padding(10)
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
                Image(systemName: "fork.knife")
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

    private func workoutRow(_ entry: WorkoutEntry) -> some View {
        HStack(spacing: 10) {
            if let imageData = entry.imageData, let uiImage = PlatformImage(data: imageData) {
                Image(platformImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                Image(systemName: "flame.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.terminalAmber)
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
                    if let cal = entry.caloriesBurned {
                        Text("-\(cal) cal")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.terminalAmber)
                    }
                    if let mins = entry.durationMinutes {
                        Text("\(mins) min")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(Theme.dimText)
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { editingWorkout = entry }
    }

    /// Re-runs whenever today's step count changes (new `.task(id:)` fires on
    /// each HealthKit refresh) — AI-estimates today's step-burn from actual
    /// body stats, falling back to the local formula silently on failure.
    private func refreshStepCalories() async {
        guard let steps = healthKit.todaysSteps, steps > 0 else {
            aiStepCalories = nil
            isStepEstimateFallback = false
            return
        }
        let weight = progressEntries.first(where: { $0.weight != nil })?.weight
        let result = await StepCalorieEstimator.estimateWithAI(
            steps: steps,
            weightLbs: weight,
            heightInches: HealthProfile.heightInches,
            age: HealthProfile.age,
            sex: HealthProfile.sex
        )
        aiStepCalories = result.calories
        isStepEstimateFallback = result.isEstimateFallback
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

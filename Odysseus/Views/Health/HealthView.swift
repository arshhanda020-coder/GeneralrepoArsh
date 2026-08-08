//
//  HealthView.swift
//  Odysseus
//
//  Food + Workouts + Activity (calorie-burn timer) + Progress (physique/weight
//  journal), all under one Health tab, plus today's step count from Apple
//  Health up top.
//

import SwiftUI
import SwiftData

struct HealthView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case food, workouts, activity, progress

        var id: String { rawValue }

        var title: String {
            switch self {
            case .food: return "Food"
            case .workouts: return "Workouts"
            case .activity: return "Activity"
            case .progress: return "Progress"
            }
        }
    }

    @StateObject private var healthKit = HealthKitManager.shared
    @Query(sort: \ProgressEntry.date, order: .reverse) private var progressEntries: [ProgressEntry]
    @Query(sort: \FoodEntry.date, order: .reverse) private var foodEntries: [FoodEntry]
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var workoutEntries: [WorkoutEntry]
    @State private var tab: Tab = .food

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var overview: CalorieMath.Result? {
        let weight = progressEntries.first(where: { $0.weight != nil })?.weight
        let todaysFood = foodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let todaysWorkouts = workoutEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        let foodCalories = todaysFood.compactMap(\.calories).reduce(0, +)
        let exerciseCalories = todaysWorkouts.compactMap(\.caloriesBurned).reduce(0, +)
        return CalorieMath.todaysOverview(weight: weight, foodCalories: foodCalories, exerciseCalories: exerciseCalories)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepsCard
                // Food tab shows its own richer calorie/macro ring dashboard
                // (NutritionRingsView) — this simpler balance card would just
                // duplicate it, so it's reserved for the other three tabs.
                if tab != .food {
                    overviewCard
                }

                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .food: FoodContentView()
                case .workouts: WorkoutContentView()
                case .activity: ActivityView()
                case .progress: BodyProgressView()
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Health")
        .inlineNavigationTitle()
        .task {
            await healthKit.requestAuthorizationAndRefresh()
        }
    }

    private var stepsCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .foregroundStyle(MindMapSection.health.accentColor)
            Text("Steps today")
                .font(.caption)
                .foregroundStyle(Theme.dimText)
            Spacer()
            if let steps = healthKit.todaysSteps {
                Text("\(steps)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.primaryText)
            } else {
                Text("—")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.dimText)
            }
        }
        .padding(10)
        .glassPanel(cornerRadius: 10)
    }

    @ViewBuilder
    private var overviewCard: some View {
        if let overview {
            VStack(alignment: .leading, spacing: 8) {
                Text("TODAY'S ENERGY BALANCE")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                VStack(spacing: 6) {
                    statRow("Maintenance", "\(overview.maintenanceCalories) cal")
                    if overview.exerciseCalories > 0 {
                        statRow("+ Exercise burned", "\(overview.exerciseCalories) cal")
                    }
                    statRow("Eaten today", "\(overview.caloriesEaten) cal")
                    Divider().overlay(Theme.cardBorder)
                    HStack {
                        Text(overview.net <= 0 ? "Deficit" : "Surplus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                        Text("\(abs(overview.net)) cal")
                            .font(.subheadline.weight(.bold).monospacedDigit())
                            .foregroundStyle(overview.net <= 0 ? Theme.terminalGreen : Theme.terminalAmber)
                    }
                }
                .padding(12)
                .glassPanel(cornerRadius: 10)
            }
        } else {
            Text("Add your weight (Progress tab), height, age, and sex to see maintenance calories and today's deficit/surplus.")
                .font(.caption)
                .foregroundStyle(Theme.dimText)
                .padding(.horizontal, 2)
        }
    }

    private func statRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label).font(.caption).foregroundStyle(Theme.dimText)
            Spacer()
            Text(value).font(.caption.monospacedDigit()).foregroundStyle(Theme.primaryText)
        }
    }
}

#Preview {
    NavigationStack {
        HealthView()
    }
    .modelContainer(
        for: [FoodEntry.self, WorkoutEntry.self, ActivitySession.self, ProgressEntry.self, MonthlyReport.self],
        inMemory: true
    )
}

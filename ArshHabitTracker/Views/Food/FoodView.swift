//
//  FoodView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct FoodView: View {
    @Query(sort: \Habit.createdAt) private var allHabits: [Habit]

    @State private var editingHabit: Habit?
    @State private var logHabit: Habit?
    @State private var showingAddHabit = false

    private var habits: [Habit] { allHabits.filter { $0.category == .meals } }
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var todaysCompletions: [Completion] {
        habits.flatMap { $0.completions }.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var todaysTotals: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        let cals = todaysCompletions.compactMap { $0.calories }.reduce(0, +)
        let protein = todaysCompletions.compactMap { $0.proteinGrams }.reduce(0, +)
        let carbs = todaysCompletions.compactMap { $0.carbsGrams }.reduce(0, +)
        let fat = todaysCompletions.compactMap { $0.fatGrams }.reduce(0, +)
        return (cals, protein, carbs, fat)
    }

    private var historyCompletions: [Completion] {
        habits.flatMap { $0.completions }
            .filter { !Calendar.current.isDate($0.date, inSameDayAs: today) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                todaySection

                if todaysTotals.calories > 0 || todaysTotals.protein > 0 || todaysTotals.carbs > 0 || todaysTotals.fat > 0 {
                    macroSummary
                }

                if !historyCompletions.isEmpty {
                    historySection
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Food")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddHabit = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddHabit) {
            AddEditHabitView(habit: nil)
        }
        .sheet(item: $editingHabit) { habit in
            AddEditHabitView(habit: habit)
        }
        .sheet(item: $logHabit) { habit in
            LogEntrySheet(habit: habit)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("TODAY")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(spacing: 0) {
                if habits.isEmpty {
                    Text("No meals set up yet. Tap + to add Breakfast, Lunch, Dinner, or a snack.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                        .padding(10)
                } else {
                    ForEach(Array(habits.enumerated()), id: \.element.id) { index, habit in
                        if index > 0 {
                            Divider().overlay(Theme.cardBorder)
                        }
                        HabitRowView(habit: habit, onEdit: { editingHabit = habit }, onLog: { logHabit = habit })
                    }
                }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private var macroSummary: some View {
        HStack {
            macroStat("CAL", "\(todaysTotals.calories)")
            macroStat("PRO", String(format: "%.0fg", todaysTotals.protein))
            macroStat("CARB", String(format: "%.0fg", todaysTotals.carbs))
            macroStat("FAT", String(format: "%.0fg", todaysTotals.fat))
        }
        .padding(10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private func macroStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(.white)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOG")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(spacing: 0) {
                ForEach(Array(historyCompletions.prefix(30).enumerated()), id: \.offset) { index, completion in
                    if index > 0 {
                        Divider().overlay(Theme.cardBorder)
                    }
                    historyRow(completion)
                }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private func historyRow(_ completion: Completion) -> some View {
        HStack(spacing: 10) {
            if let imageData = completion.imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(completion.habit?.name ?? "Meal")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                if let note = completion.note, !note.isEmpty {
                    Text(note)
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                        .lineLimit(1)
                }
            }
            Spacer()
            Text(completion.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.dimText)
        }
        .padding(10)
    }
}

#Preview {
    NavigationStack {
        FoodView()
    }
    .modelContainer(for: [Habit.self, Completion.self], inMemory: true)
}

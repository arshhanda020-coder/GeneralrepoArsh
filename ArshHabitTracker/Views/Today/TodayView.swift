//
//  TodayView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct TodayView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]

    @State private var showingAddHabit = false
    @State private var editingHabit: Habit?
    @State private var mealNoteHabit: Habit?

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var scheduledToday: [Habit] {
        habits.filter { $0.isScheduled(on: today) }
    }

    private var notScheduledToday: [Habit] {
        habits.filter { !$0.isScheduled(on: today) }
    }

    private var doneCount: Int {
        scheduledToday.filter { $0.isCompleted(on: today) }.count
    }

    private var totalCount: Int { scheduledToday.count }

    private var momentum: Double {
        totalCount == 0 ? 0 : Double(doneCount) / Double(totalCount)
    }

    private var groupedScheduled: [(category: HabitCategory, items: [Habit])] {
        let groups = Dictionary(grouping: scheduledToday, by: { $0.category })
        return HabitCategory.allCases.compactMap { category in
            guard let items = groups[category], !items.isEmpty else { return nil }
            return (category, items)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                progressBar

                ForEach(groupedScheduled, id: \.category) { entry in
                    categorySection(category: entry.category, items: entry.items)
                }

                if !notScheduledToday.isEmpty {
                    notScheduledSection
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(today.formatted(.dateTime.weekday(.wide).month(.wide).day()))
        .navigationBarTitleDisplayMode(.inline)
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
        .sheet(item: $mealNoteHabit) { habit in
            MealLogSheet(habit: habit)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Let's level up")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Spacer()
            Text("\(Int(momentum * 100))%")
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(Color(hex: "4ADE80"))
        }
    }

    private var progressBar: some View {
        VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Theme.cardBorder)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: "4ADE80"))
                        .frame(width: geo.size.width * momentum)
                        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: momentum)
                }
            }
            .frame(height: 6)

            Text("\(doneCount) of \(totalCount) scheduled items done today")
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
    }

    @ViewBuilder
    private func categorySection(category: HabitCategory, items: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(category.emoji)
                    .font(.caption)
                Text(category.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(category.accentColor)
                Spacer()
                Text("\(items.filter { $0.isCompleted(on: today) }.count)/\(items.count)")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
            }

            groupedList(items)
        }
    }

    private var notScheduledSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("NOT SCHEDULED TODAY")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            groupedList(notScheduledToday)
                .opacity(0.45)
        }
    }

    private func groupedList(_ items: [Habit]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, habit in
                if index > 0 {
                    Divider().overlay(Theme.cardBorder)
                }
                HabitRowView(
                    habit: habit,
                    onEdit: { editingHabit = habit },
                    onLogMeal: { mealNoteHabit = habit }
                )
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .modelContainer(for: [Habit.self, Completion.self, Skill.self, SkillSession.self], inMemory: true)
}

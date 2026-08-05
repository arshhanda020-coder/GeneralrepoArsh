//
//  WorkoutView.swift
//  ArshHabitTracker
//
//  Workouts sub-tab within Health — no own nav title/toolbar since it's
//  embedded in HealthView's segmented picker.
//

import SwiftUI
import SwiftData

struct WorkoutContentView: View {
    @Query(sort: \Habit.createdAt) private var allHabits: [Habit]

    @State private var editingHabit: Habit?
    @State private var logHabit: Habit?
    @State private var showingAddHabit = false

    private var habits: [Habit] { allHabits.filter { $0.category == .workouts } }
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var historyCompletions: [Completion] {
        habits.flatMap { $0.completions }
            .filter { !Calendar.current.isDate($0.date, inSameDayAs: today) }
            .sorted { $0.date > $1.date }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            todaySection

            if !historyCompletions.isEmpty {
                historySection
            }
        }
        .sheet(isPresented: $showingAddHabit) {
            AddEditHabitView(habit: nil, lockedCategory: .workouts)
        }
        .sheet(item: $editingHabit) { habit in
            AddEditHabitView(habit: habit, lockedCategory: .workouts)
        }
        .sheet(item: $logHabit) { habit in
            LogEntrySheet(habit: habit)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TODAY")
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button {
                    showingAddHabit = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MindMapSection.health.accentColor)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                if habits.isEmpty {
                    Text("No workouts set up yet. Tap + to add one.")
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
                Text(completion.habit?.name ?? "Workout")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
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
        WorkoutContentView()
    }
    .modelContainer(for: [Habit.self, Completion.self], inMemory: true)
}

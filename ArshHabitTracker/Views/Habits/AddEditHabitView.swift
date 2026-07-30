//
//  AddEditHabitView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct AddEditHabitView: View {
    let habit: Habit?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "⭐️"
    @State private var colorHex = HabitCategory.newHabits.accentHex
    @State private var category: HabitCategory = .newHabits
    @State private var scheduledDays: Set<Int> = []
    @State private var remindersOn = false
    @State private var reminderTime = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: .now) ?? .now

    private let emojiOptions = ["⭐️", "📚", "🏋️", "🚶", "🍳", "✨", "🌙", "☀️", "📖", "📰", "📊", "🐍", "🗂️", "🏆", "🧾", "💧", "🧘", "🎯", "🧠", "🎨"]
    private let colorOptions = ["5B8CFF", "FF6B6B", "FFB84D", "FF8FD1", "4ADE80", "A78BFA", "38BDF8", "F472B6"]
    private let weekdaySymbols = ["S", "M", "T", "W", "T", "F", "S"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Habit") {
                    TextField("Name", text: $name)
                    Picker("Emoji", selection: $emoji) {
                        ForEach(emojiOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    colorPicker
                }

                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(HabitCategory.allCases) { cat in
                            Text("\(cat.emoji) \(cat.displayName)").tag(cat)
                        }
                    }
                    .onChange(of: category) { _, newValue in
                        if habit == nil { colorHex = newValue.accentHex }
                    }
                }

                Section("Schedule") {
                    weekdayToggle
                    Text(scheduledDays.isEmpty ? "Every day" : "Selected days only")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }

                Section("Reminder") {
                    Toggle("Remind me", isOn: $remindersOn)
                    if remindersOn {
                        DatePicker("Time", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                }

                if habit != nil {
                    Section {
                        Button("Delete habit", role: .destructive) { deleteHabit() }
                    }
                }
            }
            .navigationTitle(habit == nil ? "New Habit" : "Edit Habit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: populateIfEditing)
        }
    }

    private var colorPicker: some View {
        HStack {
            Text("Color")
            Spacer()
            ForEach(colorOptions, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(.white, lineWidth: colorHex == hex ? 2 : 0))
                    .onTapGesture { colorHex = hex }
            }
        }
    }

    private var weekdayToggle: some View {
        HStack(spacing: 8) {
            ForEach(1...7, id: \.self) { day in
                let isOn = scheduledDays.contains(day)
                Text(weekdaySymbols[day - 1])
                    .font(.caption.weight(.semibold))
                    .frame(width: 30, height: 30)
                    .background(isOn ? Color(hex: colorHex) : Theme.cardBorder)
                    .foregroundStyle(isOn ? .black : Theme.dimText)
                    .clipShape(Circle())
                    .onTapGesture {
                        if isOn {
                            scheduledDays.remove(day)
                        } else {
                            scheduledDays.insert(day)
                        }
                    }
            }
        }
    }

    private func populateIfEditing() {
        guard let habit else {
            colorHex = category.accentHex
            return
        }
        name = habit.name
        emoji = habit.emoji
        colorHex = habit.colorHex
        category = habit.category
        scheduledDays = Set(habit.scheduledDays)
        remindersOn = habit.remindersOn
        reminderTime = Calendar.current.date(
            bySettingHour: habit.reminderHour,
            minute: habit.reminderMinute,
            second: 0,
            of: .now
        ) ?? .now
    }

    private func save() {
        let hour = Calendar.current.component(.hour, from: reminderTime)
        let minute = Calendar.current.component(.minute, from: reminderTime)
        let targetHabit: Habit

        if let habit {
            habit.name = name
            habit.emoji = emoji
            habit.colorHex = colorHex
            habit.category = category
            habit.scheduledDays = Array(scheduledDays).sorted()
            habit.remindersOn = remindersOn
            habit.reminderHour = hour
            habit.reminderMinute = minute
            targetHabit = habit
        } else {
            let newHabit = Habit(
                name: name,
                emoji: emoji,
                colorHex: colorHex,
                category: category,
                scheduledDays: Array(scheduledDays).sorted(),
                remindersOn: remindersOn,
                reminderHour: hour,
                reminderMinute: minute
            )
            modelContext.insert(newHabit)
            targetHabit = newHabit
        }

        NotificationManager.shared.sync(habit: targetHabit)
        dismiss()
    }

    private func deleteHabit() {
        if let habit {
            NotificationManager.shared.cancel(habit: habit)
            modelContext.delete(habit)
        }
        dismiss()
    }
}

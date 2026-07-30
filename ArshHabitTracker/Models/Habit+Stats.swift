//
//  Habit+Stats.swift
//  ArshHabitTracker
//

import Foundation

struct HabitDayRecord: Identifiable {
    let id = UUID()
    let date: Date
    let scheduled: Bool
    let completed: Bool
}

extension Habit {
    private var calendar: Calendar { Calendar.current }

    func isScheduled(on date: Date) -> Bool {
        if scheduledDays.isEmpty { return true }
        let weekday = calendar.component(.weekday, from: date)
        return scheduledDays.contains(weekday)
    }

    func isCompleted(on date: Date) -> Bool {
        let day = calendar.startOfDay(for: date)
        return completions.contains { calendar.isDate($0.date, inSameDayAs: day) }
    }

    /// Consecutive scheduled+completed days counting back from today.
    /// An unfinished today does not break the streak.
    var currentStreak: Int {
        let today = calendar.startOfDay(for: Date())
        let earliestDay = calendar.startOfDay(for: createdAt)
        var day = today
        var streak = 0
        var isFirstDay = true

        while day >= earliestDay {
            if isScheduled(on: day) {
                if isCompleted(on: day) {
                    streak += 1
                } else if !isFirstDay {
                    break
                }
            }
            isFirstDay = false
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return streak
    }

    var bestStreak: Int {
        let today = calendar.startOfDay(for: Date())
        var day = calendar.startOfDay(for: createdAt)
        var current = 0
        var best = 0

        while day <= today {
            if isScheduled(on: day) {
                if isCompleted(on: day) {
                    current += 1
                    best = max(best, current)
                } else {
                    current = 0
                }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return best
    }

    var thirtyDayRate: Double {
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -29, to: today) else { return 0 }
        var day = start
        var scheduledCount = 0
        var completedCount = 0

        while day <= today {
            if isScheduled(on: day) {
                scheduledCount += 1
                if isCompleted(on: day) { completedCount += 1 }
            }
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return scheduledCount == 0 ? 0 : Double(completedCount) / Double(scheduledCount)
    }

    func history(days: Int) -> [HabitDayRecord] {
        let today = calendar.startOfDay(for: Date())
        var records: [HabitDayRecord] = []
        for offset in stride(from: days - 1, through: 0, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            records.append(HabitDayRecord(date: day, scheduled: isScheduled(on: day), completed: isCompleted(on: day)))
        }
        return records
    }
}

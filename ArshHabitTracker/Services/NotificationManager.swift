//
//  NotificationManager.swift
//  ArshHabitTracker
//

import Foundation
import UserNotifications

@MainActor
final class NotificationManager {
    static let shared = NotificationManager()

    private let center = UNUserNotificationCenter.current()

    private init() {}

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// Cancels any existing reminders for this habit, then reschedules if reminders are on.
    func sync(habit: Habit) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: habit))
        guard habit.remindersOn else { return }

        let habitID = habit.id
        let name = habit.name
        let emoji = habit.emoji
        let weekdays = habit.scheduledDays.isEmpty ? Array(1...7) : habit.scheduledDays
        let hour = habit.reminderHour
        let minute = habit.reminderMinute

        Task {
            await requestAuthorizationIfNeeded()
            for weekday in weekdays {
                var dateComponents = DateComponents()
                dateComponents.weekday = weekday
                dateComponents.hour = hour
                dateComponents.minute = minute

                let content = UNMutableNotificationContent()
                content.title = "\(emoji) \(name)"
                content.body = "Time to level up — log it now."
                content.sound = .default

                let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
                let request = UNNotificationRequest(
                    identifier: identifier(habitID: habitID, weekday: weekday),
                    content: content,
                    trigger: trigger
                )
                try? await center.add(request)
            }
        }
    }

    func cancel(habit: Habit) {
        center.removePendingNotificationRequests(withIdentifiers: identifiers(for: habit))
    }

    private static let suggestionIdentifier = "copilot-daily-suggestion"

    /// Schedules a one-off local notification a few hours out with an AI-generated
    /// suggestion. There's no backend here, so this can't be a silent server push —
    /// it's a real local notification, seeded with content generated while the app
    /// was open, same mechanism as habit reminders.
    func scheduleSuggestion(text: String) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.suggestionIdentifier])

        let content = UNMutableNotificationContent()
        content.title = "Copilot suggestion"
        content.body = text
        content.sound = .default

        Task {
            await requestAuthorizationIfNeeded()
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 3600, repeats: false)
            let request = UNNotificationRequest(identifier: Self.suggestionIdentifier, content: content, trigger: trigger)
            try? await center.add(request)
        }
    }

    private func identifier(habitID: String, weekday: Int) -> String {
        "habit-\(habitID)-weekday-\(weekday)"
    }

    private func identifiers(for habit: Habit) -> [String] {
        (1...7).map { identifier(habitID: habit.id, weekday: $0) }
    }

    // MARK: - Generic one-off due-date reminders
    // Shared by project task milestones, assignment due dates, and anything
    // else that just needs "remind me once, at this date/time."

    /// Fires at 9am on the given date. Silently does nothing if the date has
    /// already passed (no point scheduling a reminder for the past).
    func scheduleOneOff(identifier: String, title: String, body: String, date: Date) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = 9
        comps.minute = 0
        guard let fireDate = Calendar.current.date(from: comps), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        Task {
            await requestAuthorizationIfNeeded()
            try? await center.add(request)
        }
    }

    func cancelOneOff(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func sync(projectTask task: ProjectTask) {
        let id = "project-task-\(task.id)"
        guard task.remindersOn, let dueDate = task.dueDate, !task.isDone else {
            cancelOneOff(identifier: id)
            return
        }
        let projectName = task.project?.name ?? "Project"
        scheduleOneOff(identifier: id, title: projectName, body: "\(task.title) is due today.", date: dueDate)
    }

    func sync(assignment: Assignment) {
        let id = "assignment-\(assignment.id)"
        guard assignment.remindersOn, let dueDate = assignment.dueDate, !assignment.isDone else {
            cancelOneOff(identifier: id)
            return
        }
        scheduleOneOff(identifier: id, title: "Assignment due", body: assignment.title, date: dueDate)
    }
}

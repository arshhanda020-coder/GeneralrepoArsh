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
}

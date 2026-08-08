//
//  NotificationManager.swift
//  Odysseus
//
//  Every local notification the app sends goes through here — due-date
//  reminders, "you forgot to..." nudges, new-content pings, and one-off
//  "here's your thing" confirmations. Each family is gated by a
//  NotificationSettings toggle so Settings can turn a category off and
//  have it actually stop (including sweeping anything already scheduled).
//
//  There's no backend/push infrastructure here, so everything is a real
//  local UNUserNotificationCenter request. "Remind me if I forgot"
//  therefore works by re-evaluating current state (has this been logged
//  today? is this still overdue?) every time the app comes to the
//  foreground and re-scheduling accordingly — see `resyncAllReminders`.
//

import Foundation
import SwiftData
import UserNotifications

#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

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

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// iOS: the app's Settings page. macOS: the system Notifications pane —
    /// there's no per-app deep link on Mac, so this is the closest thing.
    func openSystemSettings() {
        #if os(iOS)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #elseif os(macOS)
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else { return }
        NSWorkspace.shared.open(url)
        #endif
    }

    private static let suggestionIdentifier = "copilot-daily-suggestion"

    /// Schedules a one-off local notification a few hours out with an AI-generated
    /// suggestion. There's no backend here, so this can't be a silent server push —
    /// it's a real local notification, seeded with content generated while the app
    /// was open.
    func scheduleSuggestion(text: String) {
        center.removePendingNotificationRequests(withIdentifiers: [Self.suggestionIdentifier])
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }

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

    // MARK: - Generic one-off due-date reminders
    // Shared by project task milestones, assignment due dates, and anything
    // else that just needs "remind me once, at this date/time."

    /// Fires at `hour:minute` (9am by default) on the given date. Silently
    /// does nothing if that moment has already passed — no point scheduling
    /// a reminder for the past.
    func scheduleOneOff(identifier: String, title: String, body: String, date: Date, hour: Int = 9, minute: Int = 0) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        comps.hour = hour
        comps.minute = minute
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

    /// Convenience for the "item got deleted" call sites — clears both the
    /// due-date reminder and whatever follow-up nudge it owns, so callers
    /// don't need to know the identifier scheme.
    func cancelReminders(assignmentID id: String) {
        cancelOneOff(identifier: "assignment-due-\(id)")
        cancelOneOff(identifier: "assignment-overdue-\(id)")
    }

    func cancelReminders(projectTaskID id: String) {
        cancelOneOff(identifier: "project-task-due-\(id)")
        cancelOneOff(identifier: "project-task-overdue-\(id)")
    }

    func cancelReminders(examID id: String) {
        cancelOneOff(identifier: "exam-due-\(id)")
        cancelOneOff(identifier: "exam-score-\(id)")
    }

    /// Schedules a one-off "you forgot to..." nudge for the next occurrence
    /// of `hour:minute` — today if that time hasn't passed yet, tomorrow
    /// otherwise. Unlike `scheduleOneOff`, this never silently no-ops: it's
    /// meant to be re-called every time the app opens and the underlying
    /// condition is still true, which keeps rolling the nudge forward one
    /// day at a time until whatever was missing gets logged/done.
    private func scheduleNudge(identifier: String, title: String, body: String, hour: Int = 20, minute: Int = 0) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        let calendar = Calendar.current
        let now = Date.now
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        guard var fireDate = calendar.date(from: comps) else { return }
        if fireDate <= now {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }
        let fireComps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: fireComps, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)

        Task {
            await requestAuthorizationIfNeeded()
            try? await center.add(request)
        }
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.month(.abbreviated).day())
    }

    // MARK: - Due-date reminders (also own the matching overdue nudge)

    func sync(assignment: Assignment) {
        let dueID = "assignment-due-\(assignment.id)"
        let overdueID = "assignment-overdue-\(assignment.id)"

        guard assignment.remindersOn, let dueDate = assignment.dueDate, !assignment.isDone,
              NotificationSettings.masterEnabled, NotificationSettings.dueDatesEnabled else {
            cancelOneOff(identifier: dueID)
            cancelOneOff(identifier: overdueID)
            return
        }

        if Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: .now) {
            cancelOneOff(identifier: dueID)
            guard NotificationSettings.stayOnTrackEnabled else {
                cancelOneOff(identifier: overdueID)
                return
            }
            scheduleNudge(identifier: overdueID, title: "Still due", body: "\(assignment.title) was due \(Self.shortDate(dueDate)) and isn't marked done yet.", hour: 9)
        } else {
            cancelOneOff(identifier: overdueID)
            scheduleOneOff(identifier: dueID, title: "Assignment due", body: assignment.title, date: dueDate)
        }
    }

    func sync(projectTask task: ProjectTask) {
        let dueID = "project-task-due-\(task.id)"
        let overdueID = "project-task-overdue-\(task.id)"

        guard task.remindersOn, let dueDate = task.dueDate, !task.isDone,
              NotificationSettings.masterEnabled, NotificationSettings.dueDatesEnabled else {
            cancelOneOff(identifier: dueID)
            cancelOneOff(identifier: overdueID)
            return
        }

        let projectName = task.project?.name ?? "Project"
        if Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: .now) {
            cancelOneOff(identifier: dueID)
            guard NotificationSettings.stayOnTrackEnabled else {
                cancelOneOff(identifier: overdueID)
                return
            }
            scheduleNudge(identifier: overdueID, title: projectName, body: "\(task.title) was due \(Self.shortDate(dueDate)) and isn't done yet.", hour: 9)
        } else {
            cancelOneOff(identifier: overdueID)
            scheduleOneOff(identifier: dueID, title: projectName, body: "\(task.title) is due today.", date: dueDate)
        }
    }

    /// Exams own two independent reminders: the due-date one (toggled by
    /// `remindersOn`, same as assignments/tasks) and a "log your score"
    /// nudge that isn't a toggle — it just starts once the exam date has
    /// passed and stops the moment a score is on file.
    func sync(exam: Exam) {
        let dueID = "exam-due-\(exam.id)"
        let scoreID = "exam-score-\(exam.id)"

        if exam.remindersOn, !exam.isPast, NotificationSettings.masterEnabled, NotificationSettings.dueDatesEnabled {
            scheduleOneOff(identifier: dueID, title: exam.category.displayName, body: "\(exam.name) is today.", date: exam.examDate)
        } else {
            cancelOneOff(identifier: dueID)
        }

        if exam.isPast, !exam.hasScore, NotificationSettings.masterEnabled, NotificationSettings.stayOnTrackEnabled {
            scheduleNudge(identifier: scoreID, title: "Log your score", body: "Did \(exam.name) come back yet? Log it to keep your score history current.", hour: 9)
        } else {
            cancelOneOff(identifier: scoreID)
        }
    }

    // MARK: - Missed-logging nudges

    /// Re-checks whether food/a workout has been logged recently and
    /// schedules or cancels the matching nudge. Call whenever the app comes
    /// to the foreground — cheap, idempotent, safe to call often.
    func syncMissedLogging(modelContext: ModelContext) {
        guard NotificationSettings.masterEnabled, NotificationSettings.stayOnTrackEnabled else {
            cancelOneOff(identifier: "food-nudge")
            cancelOneOff(identifier: "workout-nudge")
            return
        }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let loggedFoodToday = ((try? modelContext.fetch(FetchDescriptor<FoodEntry>())) ?? [])
            .contains { calendar.isDate($0.date, inSameDayAs: today) }
        if loggedFoodToday {
            cancelOneOff(identifier: "food-nudge")
        } else {
            scheduleNudge(identifier: "food-nudge", title: "Nothing logged today", body: "You haven't logged any food yet today.")
        }

        let lastWorkoutDate = ((try? modelContext.fetch(FetchDescriptor<WorkoutEntry>())) ?? []).map(\.date).max()
        let daysSinceWorkout = lastWorkoutDate.map { calendar.dateComponents([.day], from: calendar.startOfDay(for: $0), to: today).day ?? 0 }
        if let daysSinceWorkout, daysSinceWorkout < 3 {
            cancelOneOff(identifier: "workout-nudge")
        } else {
            let body = lastWorkoutDate == nil
                ? "You haven't logged a workout yet."
                : "It's been \(daysSinceWorkout ?? 3)+ days since your last logged workout."
            scheduleNudge(identifier: "workout-nudge", title: "Workout check-in", body: body)
        }
    }

    /// The single entry point for "catch me up" — re-evaluates every
    /// due-date reminder, overdue nudge, score nudge, and missed-logging
    /// nudge against current data. Cheap enough to call on every app
    /// foreground (a handful of fetches), and it's how overdue/forgot-to
    /// nudges activate over time without needing a hook at every place
    /// data could change.
    func resyncAllReminders(modelContext: ModelContext) {
        let assignments = (try? modelContext.fetch(FetchDescriptor<Assignment>())) ?? []
        for assignment in assignments { sync(assignment: assignment) }

        let tasks = (try? modelContext.fetch(FetchDescriptor<ProjectTask>())) ?? []
        for task in tasks { sync(projectTask: task) }

        let exams = (try? modelContext.fetch(FetchDescriptor<Exam>())) ?? []
        for exam in exams { sync(exam: exam) }

        syncMissedLogging(modelContext: modelContext)
    }

    // MARK: - New-content pings (fire immediately, not scheduled)

    /// Fires immediately whenever a refresh turns up Innovation items the
    /// user hasn't seen before.
    func notifyNewInnovation(count: Int, firstTitle: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.newsAndInnovationEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "New in AI Tools"
        content.body = count == 1 ? firstTitle : "\(count) new finds, including: \(firstTitle)"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "ai-tools-innovation-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        Task {
            await requestAuthorizationIfNeeded()
            try? await center.add(request)
        }
    }

    /// Fires immediately whenever a News tab refresh turns up headlines the
    /// user hasn't seen before, for a given topic.
    func notifyNewHeadlines(topic: String, count: Int, firstTitle: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.newsAndInnovationEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "New in \(topic)"
        content.body = count == 1 ? firstTitle : "\(count) new headlines, including: \(firstTitle)"
        content.sound = .default
        let request = UNNotificationRequest(
            identifier: "news-new-\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        Task {
            await requestAuthorizationIfNeeded()
            try? await center.add(request)
        }
    }

    /// Fires immediately once a progress report finishes generating — it's
    /// AI-drafted and can take a few seconds, long enough that the user may
    /// have already navigated away.
    func notifyReportReady(periodLabel: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Progress report ready"
        content.body = "Your \(periodLabel) summary is ready to read."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "report-ready-\(UUID().uuidString)", content: content, trigger: nil)
        Task {
            await requestAuthorizationIfNeeded()
            try? await center.add(request)
        }
    }

    /// Fires immediately once an export (resume PDF, etc.) is ready.
    func notifyExportComplete(name: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = "Export ready"
        content.body = "\(name) is ready to share."
        content.sound = .default
        let request = UNNotificationRequest(identifier: "export-complete-\(UUID().uuidString)", content: content, trigger: nil)
        Task {
            await requestAuthorizationIfNeeded()
            try? await center.add(request)
        }
    }

    // MARK: - Settings sweep

    private static let dueDatePrefixes = ["assignment-due-", "project-task-due-", "exam-due-"]
    private static let stayOnTrackPrefixes = ["assignment-overdue-", "project-task-overdue-", "exam-score-", "food-nudge", "workout-nudge"]
    private static let newsPrefixes = ["ai-tools-innovation-", "news-new-"]
    private static let updatesPrefixes = ["copilot-daily-suggestion", "report-ready-", "export-complete-"]

    /// Call after any NotificationSettings toggle changes — clears out
    /// anything already scheduled for a category that just got turned off,
    /// so flipping the switch takes effect immediately rather than waiting
    /// for the next natural cancel point.
    func sweepDisabledCategories() {
        Task {
            if !NotificationSettings.masterEnabled {
                let all = await center.pendingNotificationRequests()
                center.removePendingNotificationRequests(withIdentifiers: all.map(\.identifier))
                return
            }

            var prefixesToRemove: [String] = []
            if !NotificationSettings.dueDatesEnabled { prefixesToRemove += Self.dueDatePrefixes }
            if !NotificationSettings.stayOnTrackEnabled { prefixesToRemove += Self.stayOnTrackPrefixes }
            if !NotificationSettings.newsAndInnovationEnabled { prefixesToRemove += Self.newsPrefixes }
            if !NotificationSettings.updatesAndSummariesEnabled { prefixesToRemove += Self.updatesPrefixes }
            guard !prefixesToRemove.isEmpty else { return }

            let requests = await center.pendingNotificationRequests()
            let ids = requests.map(\.identifier).filter { id in prefixesToRemove.contains { id.hasPrefix($0) } }
            guard !ids.isEmpty else { return }
            center.removePendingNotificationRequests(withIdentifiers: ids)
        }
    }
}

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
        // .timeSensitive lets due-date/study reminders break through Focus
        // modes — see scheduleUrgentOneOff/scheduleUrgentNudge below.
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge, .timeSensitive])
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

    // MARK: - Generic one-off reminders

    func cancelOneOff(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    /// Convenience for the "item got deleted" call sites — clears both the
    /// due-date reminder and whatever follow-up nudge it owns, so callers
    /// don't need to know the identifier scheme.
    func cancelReminders(assignmentID id: String) {
        cancelUrgentOneOff(identifier: "assignment-due-\(id)")
        cancelUrgentOneOff(identifier: "assignment-overdue-\(id)")
    }

    func cancelReminders(projectTaskID id: String) {
        cancelUrgentOneOff(identifier: "project-task-due-\(id)")
        cancelUrgentOneOff(identifier: "project-task-overdue-\(id)")
    }

    func cancelReminders(examID id: String) {
        cancelUrgentOneOff(identifier: "exam-due-\(id)")
        cancelUrgentOneOff(identifier: "exam-score-\(id)")
    }

    /// Schedules a one-off "you forgot to..." nudge for the next occurrence
    /// of `hour:minute` — today if that time hasn't passed yet, tomorrow
    /// otherwise. Unlike a plain calendar-date reminder, this never silently
    /// no-ops: it's meant to be re-called every time the app opens and the
    /// underlying condition is still true, which keeps rolling the nudge
    /// forward one day at a time until whatever was missing gets logged/done.
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

    // MARK: - Urgent (due-date / study) reminders
    //
    // iOS doesn't let a single local notification define its own vibration
    // pattern — the OS controls that. "Make it buzz a lot" is approximated
    // two ways instead: mark it Time Sensitive (so it breaks through Focus
    // modes and gets the more insistent system treatment) and fire it as a
    // short burst of 3 notifications a few minutes apart instead of one,
    // so a due date/exam actually pulses your phone a few times instead of
    // a single easy-to-miss buzz.

    private static let urgentBurstOffsetsMinutes = [0, 4, 9]

    private func scheduleUrgentBurst(baseIdentifier: String, title: String, body: String, firstFireDate: Date) {
        let calendar = Calendar.current
        for (index, offsetMinutes) in Self.urgentBurstOffsetsMinutes.enumerated() {
            guard let fireDate = calendar.date(byAdding: .minute, value: offsetMinutes, to: firstFireDate), fireDate > .now else { continue }
            let id = index == 0 ? baseIdentifier : "\(baseIdentifier)-echo\(index)"
            let comps = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)

            Task {
                await requestAuthorizationIfNeeded()
                try? await center.add(request)
            }
        }
    }

    /// Schedules a due-date reminder — fires at the given date's own time of
    /// day, or `hour:minute` (default 9am) if it's just a bare day (midnight
    /// — the case for anything scheduled through the date-only picker UI, or
    /// a Copilot call that didn't specify a time). Does nothing if that
    /// moment's already passed.
    private func scheduleUrgentOneOff(identifier: String, title: String, body: String, date: Date, hour: Int = 9, minute: Int = 0) {
        cancelUrgentOneOff(identifier: identifier)
        var comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        if comps.hour == 0 && comps.minute == 0 {
            comps.hour = hour
            comps.minute = minute
        }
        guard let fireDate = Calendar.current.date(from: comps), fireDate > .now else { return }
        scheduleUrgentBurst(baseIdentifier: identifier, title: title, body: body, firstFireDate: fireDate)
    }

    /// Same as `scheduleNudge`, but for the overdue/missing-score follow-ups
    /// on due-date items — still "something's due," so it gets the same
    /// urgent treatment.
    private func scheduleUrgentNudge(identifier: String, title: String, body: String, hour: Int = 9, minute: Int = 0) {
        cancelUrgentOneOff(identifier: identifier)
        let calendar = Calendar.current
        let now = Date.now
        var comps = calendar.dateComponents([.year, .month, .day], from: now)
        comps.hour = hour
        comps.minute = minute
        guard var fireDate = calendar.date(from: comps) else { return }
        if fireDate <= now {
            fireDate = calendar.date(byAdding: .day, value: 1, to: fireDate) ?? fireDate
        }
        scheduleUrgentBurst(baseIdentifier: identifier, title: title, body: body, firstFireDate: fireDate)
    }

    /// Cancels an urgent reminder and its echo(es) — the burst's follow-up
    /// notifications share the base identifier plus a suffix.
    private func cancelUrgentOneOff(identifier: String) {
        let ids = [identifier] + (1..<Self.urgentBurstOffsetsMinutes.count).map { "\(identifier)-echo\($0)" }
        center.removePendingNotificationRequests(withIdentifiers: ids)
    }

    // MARK: - Due-date reminders (also own the matching overdue nudge)

    func sync(assignment: Assignment) {
        let dueID = "assignment-due-\(assignment.id)"
        let overdueID = "assignment-overdue-\(assignment.id)"

        guard assignment.remindersOn, let dueDate = assignment.dueDate, !assignment.isDone,
              NotificationSettings.masterEnabled, NotificationSettings.dueDatesEnabled else {
            cancelUrgentOneOff(identifier: dueID)
            cancelUrgentOneOff(identifier: overdueID)
            return
        }

        if Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: .now) {
            cancelUrgentOneOff(identifier: dueID)
            guard NotificationSettings.stayOnTrackEnabled else {
                cancelUrgentOneOff(identifier: overdueID)
                return
            }
            scheduleUrgentNudge(identifier: overdueID, title: "Still due", body: "\(assignment.title) was due \(Self.shortDate(dueDate)) and isn't marked done yet.", hour: 9)
        } else {
            cancelUrgentOneOff(identifier: overdueID)
            scheduleUrgentOneOff(identifier: dueID, title: "Assignment due", body: assignment.title, date: dueDate)
        }
    }

    func sync(projectTask task: ProjectTask) {
        let dueID = "project-task-due-\(task.id)"
        let overdueID = "project-task-overdue-\(task.id)"

        guard task.remindersOn, let dueDate = task.dueDate, !task.isDone,
              NotificationSettings.masterEnabled, NotificationSettings.dueDatesEnabled else {
            cancelUrgentOneOff(identifier: dueID)
            cancelUrgentOneOff(identifier: overdueID)
            return
        }

        let projectName = task.project?.name ?? "Project"
        if Calendar.current.startOfDay(for: dueDate) < Calendar.current.startOfDay(for: .now) {
            cancelUrgentOneOff(identifier: dueID)
            guard NotificationSettings.stayOnTrackEnabled else {
                cancelUrgentOneOff(identifier: overdueID)
                return
            }
            scheduleUrgentNudge(identifier: overdueID, title: projectName, body: "\(task.title) was due \(Self.shortDate(dueDate)) and isn't done yet.", hour: 9)
        } else {
            cancelUrgentOneOff(identifier: overdueID)
            scheduleUrgentOneOff(identifier: dueID, title: projectName, body: "\(task.title) is due today.", date: dueDate)
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
            scheduleUrgentOneOff(identifier: dueID, title: exam.category.displayName, body: "\(exam.name) is today.", date: exam.examDate)
        } else {
            cancelUrgentOneOff(identifier: dueID)
        }

        if exam.isPast, !exam.hasScore, NotificationSettings.masterEnabled, NotificationSettings.stayOnTrackEnabled {
            scheduleUrgentNudge(identifier: scoreID, title: "Log your score", body: "Did \(exam.name) come back yet? Log it to keep your score history current.", hour: 9)
        } else {
            cancelUrgentOneOff(identifier: scoreID)
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

    // MARK: - Fire-and-forget pings (fire immediately, not scheduled)

    private func fireImmediate(identifier: String, title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        Task {
            await requestAuthorizationIfNeeded()
            try? await center.add(request)
        }
    }

    /// Fires immediately whenever a refresh turns up Innovation items the
    /// user hasn't seen before.
    func notifyNewInnovation(count: Int, firstTitle: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.newsAndInnovationEnabled else { return }
        let body = count == 1 ? firstTitle : "\(count) new finds, including: \(firstTitle)"
        fireImmediate(identifier: "ai-tools-innovation-\(UUID().uuidString)", title: "New in AI Tools", body: body)
    }

    /// Fires immediately whenever a News tab refresh turns up headlines the
    /// user hasn't seen before, for a given topic.
    func notifyNewHeadlines(topic: String, count: Int, firstTitle: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.newsAndInnovationEnabled else { return }
        let body = count == 1 ? firstTitle : "\(count) new headlines, including: \(firstTitle)"
        fireImmediate(identifier: "news-new-\(UUID().uuidString)", title: "New in \(topic)", body: body)
    }

    /// Fires immediately once a progress report finishes generating — it's
    /// AI-drafted and can take a few seconds, long enough that the user may
    /// have already navigated away.
    func notifyReportReady(periodLabel: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        fireImmediate(identifier: "report-ready-\(UUID().uuidString)", title: "Progress report ready", body: "Your \(periodLabel) summary is ready to read.")
    }

    /// Fires immediately once an export (resume PDF, etc.) is ready.
    func notifyExportComplete(name: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        fireImmediate(identifier: "export-complete-\(UUID().uuidString)", title: "Export ready", body: "\(name) is ready to share.")
    }

    /// Fires immediately when an assignment or project task gets checked off.
    func notifyTaskCompleted(title: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        fireImmediate(identifier: "task-done-\(UUID().uuidString)", title: "Nice work", body: "\(title) — done.")
    }

    /// Fires immediately once a practice test/quiz has been generated and is
    /// ready to take.
    func notifyPracticeTestCreated(topic: String, questionCount: Int) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        let body = "\(topic) — \(questionCount) question\(questionCount == 1 ? "" : "s") ready."
        fireImmediate(identifier: "quiz-created-\(UUID().uuidString)", title: "Practice test ready", body: body)
    }

    /// Fires immediately after a new food entry is logged.
    func notifyFoodLogged(note: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        fireImmediate(identifier: "food-logged-\(UUID().uuidString)", title: "Food logged", body: note)
    }

    /// Fires immediately after a new workout entry is logged.
    func notifyWorkoutLogged(note: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        fireImmediate(identifier: "workout-logged-\(UUID().uuidString)", title: "Workout logged", body: note)
    }

    /// Fires immediately after a new grade/score is added.
    func notifyGradeAdded(course: String, gradeLabel: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        fireImmediate(identifier: "grade-added-\(UUID().uuidString)", title: "Score logged", body: "\(course): \(gradeLabel)")
    }

    /// Fires immediately after new class material (a topic/unit) is added.
    func notifyMaterialAdded(className: String, materialName: String) {
        guard NotificationSettings.masterEnabled, NotificationSettings.updatesAndSummariesEnabled else { return }
        fireImmediate(identifier: "material-added-\(UUID().uuidString)", title: "Added to \(className)", body: materialName)
    }

    /// Fires immediately after a due date + reminder gets set on an
    /// assignment, task, or exam — confirms the reminder actually took.
    func notifyReminderSet(title: String, date: Date) {
        guard NotificationSettings.masterEnabled, NotificationSettings.dueDatesEnabled else { return }
        fireImmediate(identifier: "reminder-set-\(UUID().uuidString)", title: "Reminder set", body: "\(title) — \(Self.shortDate(date)).")
    }

    // MARK: - Settings sweep

    private static let dueDatePrefixes = ["assignment-due-", "project-task-due-", "exam-due-", "reminder-set-"]
    private static let stayOnTrackPrefixes = ["assignment-overdue-", "project-task-overdue-", "exam-score-", "food-nudge", "workout-nudge"]
    private static let newsPrefixes = ["ai-tools-innovation-", "news-new-"]
    private static let updatesPrefixes = [
        "copilot-daily-suggestion", "report-ready-", "export-complete-",
        "task-done-", "quiz-created-", "food-logged-", "workout-logged-", "grade-added-", "material-added-",
    ]

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

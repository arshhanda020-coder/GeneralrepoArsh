//
//  NotificationSettings.swift
//  Odysseus
//
//  User-facing on/off switches for each family of local notifications.
//  NotificationManager checks these before scheduling anything; SettingsView
//  reads/writes them and sweeps pending notifications when a category gets
//  turned off, so flipping a toggle takes effect immediately, not just for
//  future scheduling.
//

import Foundation

nonisolated enum NotificationSettings {
    private static let masterKey = "notif_master_enabled"
    private static let dueDatesKey = "notif_due_dates_enabled"
    private static let stayOnTrackKey = "notif_stay_on_track_enabled"
    private static let newsKey = "notif_news_enabled"
    private static let updatesKey = "notif_updates_enabled"

    /// Everything is opt-out, not opt-in — matches the rest of the app,
    /// which doesn't gate features behind first-run setup.
    static var masterEnabled: Bool {
        get { UserDefaults.standard.object(forKey: masterKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: masterKey) }
    }

    /// Assignments, project tasks, and exams — reminders tied to a date you set.
    static var dueDatesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: dueDatesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: dueDatesKey) }
    }

    /// Nudges for things you forgot: food/workout not logged, a test score
    /// still missing, an assignment or task that's overdue and still undone.
    static var stayOnTrackEnabled: Bool {
        get { UserDefaults.standard.object(forKey: stayOnTrackKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: stayOnTrackKey) }
    }

    /// New AI Tools innovation/news finds and News tab headlines.
    static var newsAndInnovationEnabled: Bool {
        get { UserDefaults.standard.object(forKey: newsKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: newsKey) }
    }

    /// Daily Copilot suggestion, progress reports, exports finishing.
    static var updatesAndSummariesEnabled: Bool {
        get { UserDefaults.standard.object(forKey: updatesKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: updatesKey) }
    }
}

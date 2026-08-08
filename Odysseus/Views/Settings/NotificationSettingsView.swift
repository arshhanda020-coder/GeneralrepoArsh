//
//  NotificationSettingsView.swift
//  Odysseus
//
//  One master switch plus a toggle per notification family. Turning a
//  toggle off sweeps anything already scheduled in that family — see
//  NotificationManager.sweepDisabledCategories().
//

import SwiftUI
import UserNotifications

struct NotificationSettingsView: View {
    @State private var masterEnabled = NotificationSettings.masterEnabled
    @State private var dueDatesEnabled = NotificationSettings.dueDatesEnabled
    @State private var stayOnTrackEnabled = NotificationSettings.stayOnTrackEnabled
    @State private var newsEnabled = NotificationSettings.newsAndInnovationEnabled
    @State private var updatesEnabled = NotificationSettings.updatesAndSummariesEnabled
    @State private var systemStatus: UNAuthorizationStatus?

    var body: some View {
        Form {
            Section {
                systemStatusRow
            } footer: {
                Text("This is the system-level switch — iOS/macOS won't deliver anything if it's off here, no matter what's set below.")
            }

            Section {
                Toggle("Notifications", isOn: $masterEnabled)
            } footer: {
                Text("Turns every notification below on or off at once.")
            }

            Section("What you'll be notified about") {
                Toggle("Due dates", isOn: $dueDatesEnabled)
                    .disabled(!masterEnabled)
                Text("Assignments, project tasks, and exams — reminders for the date/time you set.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)

                Toggle("Stay-on-track nudges", isOn: $stayOnTrackEnabled)
                    .disabled(!masterEnabled)
                Text("Forgot to log food or a workout, a test score that's still missing, or a due date that's passed with the item still not done.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)

                Toggle("News & Innovation", isOn: $newsEnabled)
                    .disabled(!masterEnabled)
                Text("New headlines and new AI Tools finds when News/AI Tools refreshes.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)

                Toggle("Updates & summaries", isOn: $updatesEnabled)
                    .disabled(!masterEnabled)
                Text("The daily Copilot suggestion, a progress report finishing, or an export becoming ready.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            }
        }
        .navigationTitle("Notifications")
        .inlineNavigationTitle()
        .task { await refreshSystemStatus() }
        .onChange(of: masterEnabled) { _, newValue in
            NotificationSettings.masterEnabled = newValue
            NotificationManager.shared.sweepDisabledCategories()
            if newValue { Task { await NotificationManager.shared.requestAuthorizationIfNeeded() } }
        }
        .onChange(of: dueDatesEnabled) { _, newValue in
            NotificationSettings.dueDatesEnabled = newValue
            NotificationManager.shared.sweepDisabledCategories()
        }
        .onChange(of: stayOnTrackEnabled) { _, newValue in
            NotificationSettings.stayOnTrackEnabled = newValue
            NotificationManager.shared.sweepDisabledCategories()
        }
        .onChange(of: newsEnabled) { _, newValue in
            NotificationSettings.newsAndInnovationEnabled = newValue
            NotificationManager.shared.sweepDisabledCategories()
        }
        .onChange(of: updatesEnabled) { _, newValue in
            NotificationSettings.updatesAndSummariesEnabled = newValue
            NotificationManager.shared.sweepDisabledCategories()
        }
    }

    @ViewBuilder
    private var systemStatusRow: some View {
        switch systemStatus {
        case .authorized, .provisional, .ephemeral:
            Label("Allowed in system settings", systemImage: "checkmark.circle.fill")
                .foregroundStyle(Theme.terminalGreen)
        case .denied:
            Button {
                NotificationManager.shared.openSystemSettings()
            } label: {
                Label("Off in system settings — tap to enable", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.negative)
            }
        case .notDetermined:
            Text("You'll be asked to allow notifications the first time one is scheduled.")
                .font(.caption)
                .foregroundStyle(Theme.dimText)
        case .none:
            Text("Checking…")
                .font(.caption)
                .foregroundStyle(Theme.dimText)
        @unknown default:
            EmptyView()
        }
    }

    private func refreshSystemStatus() async {
        systemStatus = await NotificationManager.shared.authorizationStatus()
    }
}

#Preview {
    NavigationStack {
        NotificationSettingsView()
    }
}

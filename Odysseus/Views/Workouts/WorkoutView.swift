//
//  WorkoutView.swift
//  Odysseus
//
//  Workouts sub-tab within Health — no own nav title/toolbar since it's
//  embedded in HealthView's segmented picker. Flat log, not habit templates.
//

import SwiftUI
import SwiftData

struct WorkoutContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var allEntries: [WorkoutEntry]

    @State private var showingLog = false
    @State private var editingEntry: WorkoutEntry?

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var todaysEntries: [WorkoutEntry] { allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) } }
    private var historyEntries: [WorkoutEntry] { allEntries.filter { !Calendar.current.isDate($0.date, inSameDayAs: today) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            todaySection

            if !historyEntries.isEmpty {
                historySection
            }
        }
        .sheet(isPresented: $showingLog) {
            LogWorkoutSheet(entry: nil)
        }
        .sheet(item: $editingEntry) { entry in
            LogWorkoutSheet(entry: entry)
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("TODAY")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button {
                    showingLog = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MindMapSection.health.accentColor)
                }
                .buttonStyle(.plain)
            }
            VStack(spacing: 0) {
                if todaysEntries.isEmpty {
                    Text("Nothing logged yet today. Tap + to log a workout.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                        .padding(10)
                } else {
                    ForEach(Array(todaysEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 {
                            Divider().overlay(Theme.cardBorder)
                        }
                        entryRow(entry)
                    }
                }
            }
            .glassPanel(cornerRadius: 10)
        }
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("LOG")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(spacing: 0) {
                ForEach(Array(historyEntries.prefix(30).enumerated()), id: \.element.id) { index, entry in
                    if index > 0 {
                        Divider().overlay(Theme.cardBorder)
                    }
                    entryRow(entry)
                }
            }
            .glassPanel(cornerRadius: 10)
        }
    }

    private func entryRow(_ entry: WorkoutEntry) -> some View {
        HStack(spacing: 10) {
            if let imageData = entry.imageData, let uiImage = PlatformImage(data: imageData) {
                Image(platformImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 40, height: 40)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(entry.note)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                if entry.durationMinutes != nil || entry.caloriesBurned != nil || entry.intensity != nil {
                    HStack(spacing: 6) {
                        if let intensity = entry.intensity {
                            Text(intensity.label)
                        }
                        if let minutes = entry.durationMinutes {
                            Text(formattedDuration(minutes))
                        }
                        if let calories = entry.caloriesBurned {
                            Text(entry.isEstimateFallback ? "~\(calories) cal" : "\(calories) cal")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
                }
            }
            Spacer()
            Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.dimText)
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { editingEntry = entry }
    }

    private func formattedDuration(_ minutes: Int) -> String {
        let hours = minutes / 60
        let remainder = minutes % 60
        if hours > 0 && remainder > 0 { return "\(hours)h \(remainder)m" }
        if hours > 0 { return "\(hours)h" }
        return "\(remainder)m"
    }
}

#Preview {
    NavigationStack {
        WorkoutContentView()
    }
    .modelContainer(for: [WorkoutEntry.self], inMemory: true)
}

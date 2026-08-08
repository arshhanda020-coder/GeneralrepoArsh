//
//  FoodView.swift
//  Odysseus
//
//  Food sub-tab within Health — no own nav title/toolbar since it's embedded
//  in HealthView's segmented picker. Flat log of meals, not habit templates.
//

import SwiftUI
import SwiftData

struct FoodContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FoodEntry.date, order: .reverse) private var allEntries: [FoodEntry]

    @State private var showingLog = false
    @State private var editingEntry: FoodEntry?

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var todaysEntries: [FoodEntry] { allEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) } }
    private var historyEntries: [FoodEntry] { allEntries.filter { !Calendar.current.isDate($0.date, inSameDayAs: today) } }

    private var todaysTotals: (calories: Int, protein: Double, carbs: Double, fat: Double) {
        let cals = todaysEntries.compactMap { $0.calories }.reduce(0, +)
        let protein = todaysEntries.compactMap { $0.proteinGrams }.reduce(0, +)
        let carbs = todaysEntries.compactMap { $0.carbsGrams }.reduce(0, +)
        let fat = todaysEntries.compactMap { $0.fatGrams }.reduce(0, +)
        return (cals, protein, carbs, fat)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            todaySection

            if todaysTotals.calories > 0 || todaysTotals.protein > 0 || todaysTotals.carbs > 0 || todaysTotals.fat > 0 {
                macroSummary
            }

            if !historyEntries.isEmpty {
                historySection
            }
        }
        .sheet(isPresented: $showingLog) {
            LogFoodSheet(entry: nil)
        }
        .sheet(item: $editingEntry) { entry in
            LogFoodSheet(entry: entry)
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
                    Text("Nothing logged yet today. Tap + to log a meal or snack.")
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

    private var macroSummary: some View {
        HStack {
            macroStat("CAL", "\(todaysTotals.calories)")
            macroStat("PRO", String(format: "%.0fg", todaysTotals.protein))
            macroStat("CARB", String(format: "%.0fg", todaysTotals.carbs))
            macroStat("FAT", String(format: "%.0fg", todaysTotals.fat))
        }
        .padding(10)
        .glassPanel(cornerRadius: 10)
    }

    private func macroStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(Theme.primaryText)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
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

    private func entryRow(_ entry: FoodEntry) -> some View {
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
                if let cal = entry.calories {
                    Text("\(cal) cal")
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
}

#Preview {
    NavigationStack {
        FoodContentView()
    }
    .modelContainer(for: [FoodEntry.self], inMemory: true)
}

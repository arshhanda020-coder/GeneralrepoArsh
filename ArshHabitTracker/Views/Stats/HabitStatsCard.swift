//
//  HabitStatsCard.swift
//  ArshHabitTracker
//

import SwiftUI

struct HabitStatsCard: View {
    let habit: Habit

    private var accentColor: Color { Color(hex: habit.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Text(habit.emoji).font(.subheadline)
                Text(habit.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
            }

            if habit.category.isLoggingType {
                Text("\(habit.completions.count) logged")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            } else {
                HStack(spacing: 16) {
                    statItem(icon: "flame.fill", label: "Current", value: "\(habit.currentStreak)")
                    statItem(icon: "trophy.fill", label: "Best", value: "\(habit.bestStreak)")
                    statItem(icon: "percent", label: "30-day", value: "\(Int(habit.thirtyDayRate * 100))%")
                }

                DotMatrixView(records: habit.history(days: 28), accentColor: accentColor)
            }
        }
        .padding(10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private func statItem(icon: String, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundStyle(accentColor)
                Text(value)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
    }
}

//
//  HabitRowView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct HabitRowView: View {
    let habit: Habit
    var onEdit: () -> Void
    var onLog: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var animateCheck = false

    private var accentColor: Color { Color(hex: habit.colorHex) }
    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var todaysCompletion: Completion? {
        habit.completions.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var isDone: Bool { todaysCompletion != nil }

    var body: some View {
        HStack(spacing: 10) {
            Text(habit.emoji)
                .font(.subheadline)
                .frame(width: 20)

            Text(habit.name)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            if habit.category.isLoggingType, let note = todaysCompletion?.note, !note.isEmpty {
                Text(note)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(1)
            }

            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .font(.caption2)
                    .foregroundStyle(accentColor)
                Text("\(habit.currentStreak)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
            }
            .frame(width: 32, alignment: .trailing)

            checkButton
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .contentShape(Rectangle())
        .onTapGesture(perform: onEdit)
    }

    @ViewBuilder
    private var checkButton: some View {
        if habit.category.isLoggingType {
            Button(action: onLog) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "square.and.pencil")
                    .font(.body)
                    .foregroundStyle(isDone ? accentColor : Theme.dimText)
            }
            .buttonStyle(.plain)
        } else {
            Button(action: toggleCompletion) {
                Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(isDone ? accentColor : Theme.dimText)
                    .scaleEffect(animateCheck ? 1.2 : 1.0)
            }
            .buttonStyle(.plain)
        }
    }

    private func toggleCompletion() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
            if let completion = todaysCompletion {
                modelContext.delete(completion)
            } else {
                let completion = Completion(date: today, habit: habit)
                modelContext.insert(completion)
                animateCheck = true
            }
        }
        if animateCheck {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                animateCheck = false
            }
        }
    }
}

//
//  StatsView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \Skill.createdAt) private var skills: [Skill]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                ForEach(HabitCategory.allCases) { category in
                    let items = habits.filter { $0.category == category }
                    if !items.isEmpty {
                        categorySection(category: category, items: items)
                    }
                }

                if !skills.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("SKILLS")
                            .font(.caption2.weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Theme.dimText)

                        ForEach(skills) { skill in
                            SkillStatsRow(skill: skill)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Stats")
    }

    @ViewBuilder
    private func categorySection(category: HabitCategory, items: [Habit]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(category.emoji)
                    .font(.caption)
                Text(category.displayName.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(category.accentColor)
            }

            VStack(spacing: 6) {
                ForEach(items) { habit in
                    HabitStatsCard(habit: habit)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(for: [Habit.self, Completion.self, Skill.self, SkillSession.self], inMemory: true)
}

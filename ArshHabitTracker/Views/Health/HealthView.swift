//
//  HealthView.swift
//  ArshHabitTracker
//
//  Food + Workouts + Activity (calorie-burn timer) + Progress (physique/weight
//  journal), all under one Health tab, plus today's step count from Apple
//  Health up top.
//

import SwiftUI
import SwiftData

struct HealthView: View {
    enum Tab: String, CaseIterable, Identifiable {
        case food, workouts, activity, progress

        var id: String { rawValue }

        var title: String {
            switch self {
            case .food: return "Food"
            case .workouts: return "Workouts"
            case .activity: return "Activity"
            case .progress: return "Progress"
            }
        }
    }

    @StateObject private var healthKit = HealthKitManager.shared
    @State private var tab: Tab = .food

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                stepsCard

                Picker("Section", selection: $tab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.title).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                switch tab {
                case .food: FoodContentView()
                case .workouts: WorkoutContentView()
                case .activity: ActivityView()
                case .progress: BodyProgressView()
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Health")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await healthKit.requestAuthorizationAndRefresh()
        }
    }

    private var stepsCard: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.walk")
                .foregroundStyle(MindMapSection.health.accentColor)
            Text("Steps today")
                .font(.caption)
                .foregroundStyle(Theme.dimText)
            Spacer()
            if let steps = healthKit.todaysSteps {
                Text("\(steps)")
                    .font(.subheadline.weight(.bold).monospacedDigit())
                    .foregroundStyle(Theme.primaryText)
            } else {
                Text("—")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.dimText)
            }
        }
        .padding(10)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }
}

#Preview {
    NavigationStack {
        HealthView()
    }
    .modelContainer(
        for: [Habit.self, Completion.self, ActivitySession.self, ProgressEntry.self, MonthlyReport.self],
        inMemory: true
    )
}

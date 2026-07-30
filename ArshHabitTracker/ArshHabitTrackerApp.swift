//
//  ArshHabitTrackerApp.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

@main
struct ArshHabitTrackerApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Habit.self, Completion.self,
                Skill.self, SkillSession.self,
                Project.self, ProjectTask.self,
                NewsItem.self, ChatMessage.self
            )
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        .modelContainer(container)
    }
}

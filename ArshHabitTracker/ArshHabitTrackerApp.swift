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
        let schema = Schema([
            Habit.self, Completion.self,
            Skill.self, SkillSession.self,
            Project.self, ProjectTask.self,
            NewsItem.self, ChatMessage.self,
            AIToolItem.self, Exam.self, StudySession.self,
            Assignment.self, QuizRecord.self,
        ])
        container = Self.makeContainer(schema: schema)
    }

    /// The on-disk store can fall out of sync with the model schema whenever a
    /// @Model type gains/loses a property between installs — SwiftData throws
    /// rather than migrating automatically, and that used to take the whole
    /// app down at launch. Recover by wiping just that store and starting
    /// fresh instead of crashing every time the schema moves.
    private static func makeContainer(schema: Schema) -> ModelContainer {
        let configuration = ModelConfiguration(schema: schema)
        do {
            return try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            let storeURL = configuration.url
            for suffix in ["", "-shm", "-wal"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            do {
                return try ModelContainer(for: schema, configurations: [configuration])
            } catch {
                fatalError("Failed to create ModelContainer even after resetting the store: \(error)")
            }
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

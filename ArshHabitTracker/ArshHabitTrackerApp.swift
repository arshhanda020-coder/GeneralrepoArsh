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
            Assignment.self, QuizSession.self, QuizQuestion.self, SchoolClass.self, Topic.self,
            Extracurricular.self, EmailDraft.self, GradeScaleEntry.self, GradeEntry.self,
            ActivitySession.self, ProgressEntry.self, MonthlyReport.self,
        ])
        container = Self.makeContainer(schema: schema)
        Self.seedClassesIfNeeded(container: container)
    }

    /// One-time seed of the user's real current class schedule — not sample
    /// data, this is what they're actually enrolled in this term.
    private static func seedClassesIfNeeded(container: ModelContainer) {
        let key = "seeded_school_classes_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let classes: [(name: String, isEnrolled: Bool)] = [
            ("Ceramics 1", true),
            ("AP Computer Science", true),
            ("Honors French 3", true),
            ("Precalculus", true),
            ("AP Environmental Science", true),
            ("English 3", true),
            ("AP United States History", true),
            ("Health & Wellness 11", false),
        ]
        let context = ModelContext(container)
        for (index, entry) in classes.enumerated() {
            context.insert(SchoolClass(name: entry.name, isEnrolled: entry.isEnrolled, sortIndex: index))
        }
        try? context.save()
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

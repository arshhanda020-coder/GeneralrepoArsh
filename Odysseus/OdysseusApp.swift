//
//  OdysseusApp.swift
//  Odysseus
//

import SwiftUI
import SwiftData

@main
struct OdysseusApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            FoodEntry.self, WorkoutEntry.self,
            Skill.self, SkillSession.self,
            Project.self, ProjectTask.self,
            NewsItem.self, ChatMessage.self, ChatSession.self,
            AIToolItem.self, Exam.self, StudySession.self,
            Assignment.self, QuizSession.self, QuizQuestion.self, SchoolClass.self, Topic.self,
            Extracurricular.self, EmailDraft.self, GradeScaleEntry.self, GradeEntry.self,
            ActivitySession.self, ProgressEntry.self, MonthlyReport.self, WatchedSymbol.self,
            MemoryEntry.self, ACTSectionScore.self, ACTPrepPlan.self, SavedGitHubLink.self, ResearchEntry.self, AgentDefinition.self, AgentRun.self,
            ObsidianNote.self, DocNote.self, Note.self,
        ])
        container = Self.makeContainer(schema: schema)
        Self.seedClassesIfNeeded(container: container)
        Self.migrateOrphanedChatMessagesIfNeeded(container: container)
    }

    /// ChatMessage gained a `session` relationship when multi-thread chat
    /// history was added — any messages from before that update have no
    /// session and would otherwise silently vanish from the UI (their data
    /// isn't deleted, just no longer reachable through session-scoped
    /// queries). Group them into one "Previous Chats" thread instead of
    /// losing them from view.
    private static func migrateOrphanedChatMessagesIfNeeded(container: ModelContainer) {
        let key = "migrated_orphaned_chat_messages_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let context = ModelContext(container)
        let orphaned = (try? context.fetch(FetchDescriptor<ChatMessage>(predicate: #Predicate { $0.session == nil }))) ?? []
        guard !orphaned.isEmpty else { return }

        let session = ChatSession(title: "Previous Chats", lastActivityAt: orphaned.map(\.createdAt).max() ?? .now)
        context.insert(session)
        for message in orphaned {
            message.session = session
        }
        try? context.save()
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
        // A plain WindowGroup already gives macOS multi-window for free —
        // File > New Window (⌘N) opens another independent RootView backed
        // by the same shared SwiftData container, exactly like Mail/Notes.
        WindowGroup {
            // Follows the system's light/dark setting instead of forcing
            // dark everywhere — every Theme color has both a light and a
            // dark default (see ThemeColorSettings) so this adapts cleanly.
            RootView()
        }
        .modelContainer(container)

        #if os(macOS)
        // The native macOS Settings window (⌘,) — its own scene/window
        // rather than a sheet, which is the idiomatic Mac pattern.
        Settings {
            SettingsView()
                .modelContainer(container)
                .frame(minWidth: 480, minHeight: 420)
        }
        #endif
    }
}

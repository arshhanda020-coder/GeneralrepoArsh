//
//  SectionAssistantPrompt.swift
//  Odysseus
//
//  Builds the system prompt for each section's own AI assistant — same
//  underlying model/provider as Copilot, but scoped: a persona tailored to
//  that one section, plus a live snapshot of that section's own data
//  (fetched fresh on every message, never stale). Unlike Copilot, a section
//  assistant has no tools — it answers and advises, it doesn't edit or
//  delete anything. That keeps every section's assistant simple to reason
//  about and keeps "can actually change my data" scoped to one place.
//

import Foundation
import SwiftData

enum SectionAssistantPrompt {
    /// Placeholder text shown above the composer before the first message.
    static func openingHint(for section: MindMapSection) -> String {
        switch section {
        case .today: return "Ask what to tackle first, or how to fit everything in today."
        case .skills: return "Ask for a practice routine, or what to focus on next."
        case .projects: return "Ask how to break a project down, or what to do next."
        case .news: return "Ask about a headline, or for more context behind one."
        case .copilot: return ""
        case .stats: return "Ask how your progress is trending, or where you're behind."
        case .emails: return "Ask for wording help on a draft, or follow-up strategy."
        case .aiIntegration: return "Ask which of these tools are worth trying, or how one fits your setup."
        case .github: return "Ask what to work on next, or for help wording a README."
        case .school: return "Ask for help with a concept, an assignment, or a study plan."
        case .health: return "Ask whether today's intake fits your goals, or for workout advice."
        case .calendar: return "Ask about an overloaded day, or what to start early."
        case .extracurriculars: return "Ask how to frame an activity, or for new ideas."
        case .memory: return "Ask what's remembered about you, or whether something's still true."
        case .research: return "Ask for sources, an angle to explore, or help organizing findings."
        case .agents: return "Ask what makes a good subagent, or help wording instructions."
        case .claudeCode, .codex: return "Ask for prompt-wording advice or how to structure a run."
        case .obsidian: return "Ask to summarize a note, or how to connect ideas across notes."
        case .notes: return "Ask to summarize, outline, or improve something you've written."
        }
    }

    /// The full system prompt sent with every message in this section's
    /// thread — rebuilt on every send so the data snapshot never goes stale.
    static func systemPrompt(for section: MindMapSection, modelContext: ModelContext) -> String {
        persona(for: section) + "\n\n" + sharedGuidance + "\n\nCurrent \(section.title) data:\n" + dataSnapshot(for: section, modelContext: modelContext)
            + WritingProfile.styleInstruction + MemoryStore.contextInstruction + dateContext
    }

    private static let sharedGuidance = """
    Your tone: composed, dry-witted, understated confidence — a sharp, capable aide, not a chipper corporate \
    assistant. Warm but economical with words, never gushing or over-enthusiastic (no exclamation points, no \
    emoji). Be concise. You have no tools here — you can't add, edit, or delete anything in the app yourself, \
    only answer and advise using the data below. If the user wants something actually changed, tell them to use \
    Copilot (the app-wide assistant that can act) or make the change directly in this section.
    """

    private static var dateContext: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return "\n\nToday's date is \(formatter.string(from: .now))."
    }

    private static func persona(for section: MindMapSection) -> String {
        switch section {
        case .today:
            return "You are the Today assistant inside Odysseus — focused purely on the user's checklist for today (assignments and project tasks due today or overdue). Help them prioritize, decide what to tackle first, and think through how to realistically fit everything in."
        case .skills:
            return "You are the Skills assistant — help with deliberate practice: designing a routine, breaking a target session count into a realistic cadence, and suggesting what to focus on next for a given skill."
        case .projects:
            return "You are the Projects assistant — help plan and unstick side projects: breaking one down into concrete tasks, unblocking someone stuck, and suggesting a reasonable next milestone given how a project's tasks actually stand."
        case .news:
            return "You are the News assistant — discuss and summarize the headlines already cached here (finance, accounting, economics, AI), answer questions about them, and add context a headline alone doesn't capture."
        case .copilot:
            return "You are Odysseus."
        case .stats:
            return "You are the Stats assistant — help interpret the user's own progress data shown here (skills, projects, quiz scores): where they're strong, where they're behind, and what a healthy pace looks like."
        case .emails:
            return "You are the Emails assistant — help with wording and tone on pending drafts, follow-up strategy, and subject lines. You can't send anything or generate new drafts here (that's Copilot's job) but you can talk through the wording of what's already in front of the user."
        case .aiIntegration:
            return "You are the AI Tools assistant — help make sense of the AI news and tool discoveries tracked here: which are worth trying, how a given tool or repo might fit the user's existing setup, and general AI tooling advice."
        case .github:
            return "You are the GitHub assistant — help think through the user's repositories: what to work on next, code-review advice in the abstract, project structuring, and README or commit-message wording."
        case .school:
            return "You are the School assistant — a study and homework coach across the user's classes, assignments, exams, and ACT prep: explain concepts, help plan study time before a test, break down an assignment, and give academic strategy."
        case .health:
            return "You are the Health assistant — nutrition and fitness coaching grounded in the user's own logged food, workouts, and activity: whether intake fits their goals, workout balance and recovery, and practical, non-alarmist advice. You are not a doctor — point anything that sounds medical to an actual professional instead of diagnosing it."
        case .calendar:
            return "You are the Calendar assistant — help make sense of the merged agenda of exams, assignments, and project tasks: spot overloaded days, suggest what to move or start early, and give scheduling advice."
        case .extracurriculars:
            return "You are the Extracurriculars assistant — help develop the user's activities: framing one well (e.g. for a resume or application), suggesting realistic next steps, and brainstorming new ones aligned with their interests."
        case .memory:
            return "You are the Memory assistant — a window into what's been remembered about the user across every Copilot conversation. Help them review what's stored, explain why something might matter, or think through whether an old fact still holds."
        case .research:
            return "You are the Research assistant — help develop and refine research entries: strengthening an argument, suggesting sources or angles to explore, and organizing findings into something usable."
        case .agents:
            return "You are the Subagents assistant — help design the *other* subagents defined here: what makes a good, clearly-worded instruction set, and what recurring task actually deserves its own subagent in the first place."
        case .claudeCode, .codex:
            return "You are the assistant for the \(section.title) bridge — help with prompt wording for the CLI agent, working-directory setup, and general advice on getting good results out of a coding agent. You have no access to the bridge or the user's codebase yourself."
        case .obsidian:
            return "You are the Obsidian assistant — help make sense of the connected vault's notes: summarizing one, connecting ideas across a few, and suggesting how to organize or tag things better."
        case .notes:
            return "You are the Notes assistant — help with anything in the Notes hub (Google Docs, Notability imports, and freeform notes): summarizing, outlining, or improving how something is written."
        }
    }

    // MARK: - Data snapshots

    private static func dataSnapshot(for section: MindMapSection, modelContext: ModelContext) -> String {
        switch section {
        case .today:
            return todaySnapshot(modelContext: modelContext)
        case .skills:
            let skills = (try? modelContext.fetch(FetchDescriptor<Skill>())) ?? []
            guard !skills.isEmpty else { return "No skills tracked yet." }
            return skills.map { "- \($0.name): \($0.sessions.count)/\($0.targetSessions) sessions\($0.isLearned ? " (learned)" : "")" }.joined(separator: "\n")
        case .projects:
            let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
            guard !projects.isEmpty else { return "No projects yet." }
            return projects.map { project -> String in
                let done = project.tasks.filter(\.isDone).count
                return "- \(project.name) [\(project.status.displayName)]: \(done)/\(project.tasks.count) tasks done"
            }.joined(separator: "\n")
        case .news:
            let items = (try? modelContext.fetch(FetchDescriptor<NewsItem>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]))) ?? []
            guard !items.isEmpty else { return "No cached headlines yet." }
            return items.prefix(15).map { "- [\($0.topic.displayName)/\($0.source)] \($0.title)" }.joined(separator: "\n")
        case .copilot:
            return ""
        case .stats:
            return statsSnapshot(modelContext: modelContext)
        case .emails:
            let drafts = ((try? modelContext.fetch(FetchDescriptor<EmailDraft>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []).filter { !$0.isSent }
            guard !drafts.isEmpty else { return "No pending drafts right now." }
            return drafts.prefix(10).map { "- \($0.subject.isEmpty ? "(no subject)" : $0.subject) → \($0.recipientLabel.isEmpty ? "unlabeled recipient" : $0.recipientLabel)" }.joined(separator: "\n")
        case .aiIntegration:
            let items = (try? modelContext.fetch(FetchDescriptor<AIToolItem>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)]))) ?? []
            guard !items.isEmpty else { return "Nothing cached yet." }
            return items.prefix(15).map { "- [\($0.category)] \($0.title)" }.joined(separator: "\n")
        case .github:
            return githubSnapshot(modelContext: modelContext)
        case .school:
            return schoolSnapshot(modelContext: modelContext)
        case .health:
            return healthSnapshot(modelContext: modelContext)
        case .calendar:
            return calendarSnapshot(modelContext: modelContext)
        case .extracurriculars:
            let items = (try? modelContext.fetch(FetchDescriptor<Extracurricular>())) ?? []
            guard !items.isEmpty else { return "No activities logged yet." }
            return items.map { "- \($0.title)\($0.category.map { " [\($0)]" } ?? "")" }.joined(separator: "\n")
        case .memory:
            let entries = (try? modelContext.fetch(FetchDescriptor<MemoryEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
            guard !entries.isEmpty else { return "Nothing remembered yet." }
            return entries.prefix(30).map { "- \($0.content)" }.joined(separator: "\n")
        case .research:
            let entries = (try? modelContext.fetch(FetchDescriptor<ResearchEntry>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)]))) ?? []
            guard !entries.isEmpty else { return "No research entries yet." }
            return entries.prefix(10).map { "- [\($0.category.displayName)] \($0.topic): \($0.content.prefix(140))" }.joined(separator: "\n")
        case .agents:
            let agents = (try? modelContext.fetch(FetchDescriptor<AgentDefinition>())) ?? []
            guard !agents.isEmpty else { return "No subagents defined yet." }
            return agents.map { "- \($0.name): \($0.instructions.prefix(140)) (\($0.runs.count) run\($0.runs.count == 1 ? "" : "s"))" }.joined(separator: "\n")
        case .claudeCode, .codex:
            return "No live data available — this bridge only runs prompts through the CLI on the user's Mac; the assistant has no direct access to the bridge or their codebase."
        case .obsidian:
            let notes = (try? modelContext.fetch(FetchDescriptor<ObsidianNote>(sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]))) ?? []
            guard !notes.isEmpty else { return "No vault connected, or no notes synced yet." }
            return notes.prefix(15).map { "- \($0.title): \($0.excerpt.prefix(100))" }.joined(separator: "\n")
        case .notes:
            return notesSnapshot(modelContext: modelContext)
        }
    }

    private static func todaySnapshot(modelContext: ModelContext) -> String {
        let today = Calendar.current.startOfDay(for: .now)
        let assignments = ((try? modelContext.fetch(FetchDescriptor<Assignment>())) ?? []).filter { assignment in
            guard let due = assignment.dueDate else { return false }
            let day = Calendar.current.startOfDay(for: due)
            return day <= today && (day == today || !assignment.isDone)
        }
        let tasks = ((try? modelContext.fetch(FetchDescriptor<ProjectTask>())) ?? []).filter { task in
            guard let due = task.dueDate else { return false }
            let day = Calendar.current.startOfDay(for: due)
            return day <= today && (day == today || !task.isDone)
        }
        guard !assignments.isEmpty || !tasks.isEmpty else { return "Nothing due today or overdue." }
        var lines = assignments.map { assignment -> String in
            let overdue = assignment.dueDate.map { Calendar.current.startOfDay(for: $0) < today } ?? false
            return "- [\(assignment.isDone ? "x" : " ")] \(assignment.title)\(overdue ? " (overdue)" : "")"
        }
        lines += tasks.map { task -> String in
            let overdue = task.dueDate.map { Calendar.current.startOfDay(for: $0) < today } ?? false
            return "- [\(task.isDone ? "x" : " ")] \(task.title) (\(task.project?.name ?? "project"))\(overdue ? " (overdue)" : "")"
        }
        return lines.joined(separator: "\n")
    }

    private static func statsSnapshot(modelContext: ModelContext) -> String {
        var sections: [String] = []
        let skills = (try? modelContext.fetch(FetchDescriptor<Skill>())) ?? []
        if !skills.isEmpty {
            sections.append("Skills:\n" + skills.map { "- \($0.name): \($0.sessions.count)/\($0.targetSessions)" }.joined(separator: "\n"))
        }
        let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
        if !projects.isEmpty {
            sections.append("Projects:\n" + projects.map { project -> String in
                let done = project.tasks.filter(\.isDone).count
                return "- \(project.name): \(done)/\(project.tasks.count) tasks"
            }.joined(separator: "\n"))
        }
        let quizzes = ((try? modelContext.fetch(FetchDescriptor<QuizSession>())) ?? []).filter(\.isSubmitted)
        if !quizzes.isEmpty {
            let score = quizzes.reduce(0) { $0 + $1.score }
            let total = quizzes.reduce(0) { $0 + $1.totalQuestions }
            sections.append("Test Me: \(score)/\(total) correct across \(quizzes.count) quiz\(quizzes.count == 1 ? "" : "zes").")
        }
        return sections.isEmpty ? "No progress data logged yet." : sections.joined(separator: "\n\n")
    }

    private static func githubSnapshot(modelContext: ModelContext) -> String {
        var sections: [String] = []
        let accounts = GitHubAccountStore.accounts
        if !accounts.isEmpty {
            sections.append("Connected accounts: " + accounts.map(\.name).joined(separator: ", "))
        }
        let links = (try? modelContext.fetch(FetchDescriptor<SavedGitHubLink>(sortBy: [SortDescriptor(\.addedAt, order: .reverse)]))) ?? []
        if !links.isEmpty {
            sections.append("Saved links:\n" + links.prefix(10).map { "- \($0.repoName ?? $0.urlString)" }.joined(separator: "\n"))
        }
        return sections.isEmpty ? "No GitHub accounts connected yet." : sections.joined(separator: "\n\n")
    }

    private static func schoolSnapshot(modelContext: ModelContext) -> String {
        var sections: [String] = []
        let classes = ((try? modelContext.fetch(FetchDescriptor<SchoolClass>())) ?? []).filter(\.isEnrolled)
        if !classes.isEmpty {
            sections.append("Enrolled classes: " + classes.map(\.name).joined(separator: ", "))
        }

        let today = Calendar.current.startOfDay(for: .now)
        let openAssignments = ((try? modelContext.fetch(FetchDescriptor<Assignment>())) ?? []).filter { !$0.isDone }
        if !openAssignments.isEmpty {
            let overdueCount = openAssignments.filter { ($0.dueDate.map { Calendar.current.startOfDay(for: $0) < today }) ?? false }.count
            sections.append("Open assignments (\(openAssignments.count), \(overdueCount) overdue):\n" + openAssignments.prefix(15).map { assignment in
                "- \(assignment.title)" + (assignment.dueDate.map { " due \(shortDate($0))" } ?? "")
            }.joined(separator: "\n"))
        }

        let exams = ((try? modelContext.fetch(FetchDescriptor<Exam>())) ?? []).filter { !$0.isPast }.sorted { $0.daysUntil < $1.daysUntil }
        if !exams.isEmpty {
            sections.append("Upcoming tests:\n" + exams.prefix(10).map { exam in
                "- \(exam.name) in \(exam.daysUntil)d" + (exam.hasScore ? ", scored \(exam.actualScore ?? "")" : "")
            }.joined(separator: "\n"))
        }

        let gradedClasses = classes.filter { $0.gradeLabel != nil }
        if !gradedClasses.isEmpty {
            sections.append("Logged grades:\n" + gradedClasses.map { "- \($0.name): \($0.gradeLabel ?? "")\($0.courseLevel == .regular ? "" : " (\($0.courseLevel.displayName))")" }.joined(separator: "\n"))
        }

        let actScores = (try? modelContext.fetch(FetchDescriptor<ACTSectionScore>())) ?? []
        if let best = actScores.compactMap(\.effectiveComposite).max() {
            sections.append("Best ACT composite so far: \(best).")
        }

        return sections.isEmpty ? "No school data logged yet." : sections.joined(separator: "\n\n")
    }

    private static func healthSnapshot(modelContext: ModelContext) -> String {
        var lines: [String] = []
        let today = Calendar.current.startOfDay(for: .now)

        let food = ((try? modelContext.fetch(FetchDescriptor<FoodEntry>())) ?? []).filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        if !food.isEmpty {
            let calories = food.compactMap(\.calories).reduce(0, +)
            let protein = food.compactMap(\.proteinGrams).reduce(0, +)
            lines.append("Logged today: \(food.count) food entr\(food.count == 1 ? "y" : "ies"), \(calories) cal, \(Int(protein))g protein.")
        }

        let workouts = ((try? modelContext.fetch(FetchDescriptor<WorkoutEntry>())) ?? []).filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        if !workouts.isEmpty {
            let burned = workouts.compactMap(\.caloriesBurned).reduce(0, +)
            lines.append("Workouts today: \(workouts.count), ~\(burned) cal burned.")
        }

        if let age = HealthProfile.age {
            var profileLine = "Profile: age \(age)"
            if let sex = HealthProfile.sex, !sex.isEmpty { profileLine += ", \(sex)" }
            if let level = HealthProfile.activityLevel { profileLine += ", \(level)" }
            lines.append(profileLine + ".")
        }

        return lines.isEmpty ? "Nothing logged today yet." : lines.joined(separator: "\n")
    }

    private static func calendarSnapshot(modelContext: ModelContext) -> String {
        let today = Calendar.current.startOfDay(for: .now)
        let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today

        let exams = ((try? modelContext.fetch(FetchDescriptor<Exam>())) ?? []).filter { !$0.isPast && $0.examDate <= weekOut }
        let assignments = ((try? modelContext.fetch(FetchDescriptor<Assignment>())) ?? []).filter { !$0.isDone && (($0.dueDate.map { $0 <= weekOut }) ?? false) }
        let tasks = ((try? modelContext.fetch(FetchDescriptor<ProjectTask>())) ?? []).filter { !$0.isDone && (($0.dueDate.map { $0 <= weekOut }) ?? false) }

        guard !exams.isEmpty || !assignments.isEmpty || !tasks.isEmpty else { return "Nothing on the agenda in the next 7 days." }

        var lines = exams.map { "- \(shortDate($0.examDate)): \($0.name) (test)" }
        lines += assignments.compactMap { assignment in assignment.dueDate.map { "- \(shortDate($0)): \(assignment.title) (assignment)" } }
        lines += tasks.compactMap { task in task.dueDate.map { "- \(shortDate($0)): \(task.title) (\(task.project?.name ?? "project") task)" } }
        return lines.joined(separator: "\n")
    }

    private static func notesSnapshot(modelContext: ModelContext) -> String {
        var sections: [String] = []
        let freeform = (try? modelContext.fetch(FetchDescriptor<Note>(sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]))) ?? []
        if !freeform.isEmpty {
            sections.append("Freeform notes:\n" + freeform.prefix(10).map { "- \($0.title)" }.joined(separator: "\n"))
        }
        let docs = (try? modelContext.fetch(FetchDescriptor<DocNote>(sortBy: [SortDescriptor(\.modifiedAt, order: .reverse)]))) ?? []
        if !docs.isEmpty {
            sections.append("Imported docs:\n" + docs.prefix(10).map { "- [\($0.source.label)] \($0.title)" }.joined(separator: "\n"))
        }
        return sections.isEmpty ? "No notes yet." : sections.joined(separator: "\n\n")
    }

    private static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day())
    }
}

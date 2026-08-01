//
//  JarvisController.swift
//  ArshHabitTracker
//
//  Shared, app-wide voice assistant state. Lives above the NavigationStack
//  (mounted once in RootView) so it keeps listening no matter which screen
//  is on-screen — this is not a per-view feature.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class JarvisController: NSObject, ObservableObject {
    static let shared = JarvisController()

    enum Status {
        case idle, listening, thinking, speaking
    }

    /// Mic listening across the app (persists while the app is foregrounded).
    @Published var isActive = false
    /// Whether the full-screen takeover is currently shown.
    @Published var isExpanded = false
    @Published var status: Status = .idle
    @Published var liveTranscript = ""
    @Published var statusMessage: String?
    @Published var latestSuggestion: String?

    let voice = VoiceManager()

    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    private var silenceTimer: Timer?

    private override init() {
        super.init()
        voice.$transcript
            .receive(on: DispatchQueue.main)
            .sink { [weak self] text in
                self?.liveTranscript = text
                self?.resetSilenceTimer()
            }
            .store(in: &cancellables)
        voice.$statusMessage
            .receive(on: DispatchQueue.main)
            .sink { [weak self] message in
                if let message { self?.statusMessage = message }
            }
            .store(in: &cancellables)
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Lifecycle

    func activate() {
        guard !isActive else {
            isExpanded = true
            return
        }
        isExpanded = true
        Task {
            let granted = await voice.requestAuthorization()
            guard granted else {
                statusMessage = voice.statusMessage
                return
            }
            isActive = true
            beginListening()
        }
    }

    func deactivate() {
        isActive = false
        isExpanded = false
        silenceTimer?.invalidate()
        voice.stopListening()
        voice.stopSpeaking()
        status = .idle
        liveTranscript = ""
    }

    func collapse() {
        isExpanded = false
    }

    func expand() {
        isExpanded = true
    }

    private func beginListening() {
        guard isActive else { return }
        liveTranscript = ""
        statusMessage = nil
        status = .listening
        voice.startListening()
    }

    private func resetSilenceTimer() {
        silenceTimer?.invalidate()
        guard isActive, status == .listening,
              !liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.3, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.finishListeningTurn() }
        }
    }

    private func finishListeningTurn() {
        guard isActive, status == .listening else { return }
        let text = liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        voice.stopListening()
        guard !text.isEmpty else {
            beginListening()
            return
        }
        Task { await sendMessage(text) }
    }

    // MARK: - Sending

    func sendMessage(_ text: String, imageData: Data? = nil) async {
        guard let modelContext else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        guard AISettings.hasActiveKey else {
            statusMessage = "Add your \(AISettings.provider.displayName) API key in Copilot settings."
            status = .idle
            if isActive { beginListening() }
            return
        }

        status = .thinking
        let userMessage = ChatMessage(role: "user", content: trimmed, imageData: imageData)
        modelContext.insert(userMessage)

        let history = (try? modelContext.fetch(
            FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.createdAt)])
        )) ?? []

        do {
            let reply = try await AISettings.currentService.send(history: history) { [weak self] name, input in
                guard let self else { return "Unknown tool." }
                return await self.executeTool(name: name, input: input)
            }
            modelContext.insert(ChatMessage(role: "assistant", content: reply))

            if isActive {
                status = .speaking
                voice.speak(reply) { [weak self] in
                    guard let self else { return }
                    if self.isActive {
                        self.beginListening()
                    } else {
                        self.status = .idle
                    }
                }
            } else {
                status = .idle
            }
        } catch {
            statusMessage = error.localizedDescription
            status = .idle
            if isActive { beginListening() }
        }
    }

    // MARK: - Daily suggestion

    func refreshDailySuggestion() {
        guard let modelContext, AISettings.hasActiveKey else { return }
        let context = buildStatusContext(modelContext: modelContext)
        Task {
            guard let suggestion = try? await AISettings.currentService.suggestion(for: context) else { return }
            self.latestSuggestion = suggestion
            NotificationManager.shared.scheduleSuggestion(text: suggestion)
        }
    }

    private func buildStatusContext(modelContext: ModelContext) -> String {
        var lines: [String] = []
        lines.append(todaySummary(context: modelContext))

        let skills = (try? modelContext.fetch(FetchDescriptor<Skill>())) ?? []
        if !skills.isEmpty {
            let skillLines = skills.map { "\($0.name): \($0.sessions.count)/\($0.targetSessions) sessions" }
            lines.append("Skills:\n" + skillLines.joined(separator: "\n"))
        }

        let projects = (try? modelContext.fetch(FetchDescriptor<Project>())) ?? []
        if !projects.isEmpty {
            let projectLines = projects.map { proj -> String in
                let done = proj.tasks.filter { $0.isDone }.count
                return "\(proj.name) (\(proj.status.displayName)): \(done)/\(proj.tasks.count) tasks"
            }
            lines.append("Projects:\n" + projectLines.joined(separator: "\n"))
        }

        let today = Calendar.current.startOfDay(for: .now)
        let habits = (try? modelContext.fetch(FetchDescriptor<Habit>())) ?? []
        let mealCompletions = habits
            .filter { $0.category == .meals }
            .flatMap { $0.completions }
            .filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        if !mealCompletions.isEmpty {
            let totalCalories = mealCompletions.compactMap { $0.calories }.reduce(0, +)
            let totalProtein = mealCompletions.compactMap { $0.proteinGrams }.reduce(0, +)
            lines.append("Food logged today: \(mealCompletions.count) entries, \(totalCalories) cal, \(Int(totalProtein))g protein so far.")
        }

        let assignments = (try? modelContext.fetch(FetchDescriptor<Assignment>())) ?? []
        let dueToday = assignments.filter { !$0.isDone && $0.dueDate.map { Calendar.current.isDate($0, inSameDayAs: today) } ?? false }
        let overdue = assignments.filter { !$0.isDone && ($0.dueDate.map { $0 < today } ?? false) }
        if !dueToday.isEmpty || !overdue.isEmpty {
            var schoolLines: [String] = []
            if !overdue.isEmpty { schoolLines.append("Overdue: " + overdue.map(\.title).joined(separator: ", ")) }
            if !dueToday.isEmpty { schoolLines.append("Due today: " + dueToday.map(\.title).joined(separator: ", ")) }
            lines.append("Assignments:\n" + schoolLines.joined(separator: "\n"))
        }

        let exams = (try? modelContext.fetch(FetchDescriptor<Exam>())) ?? []
        let soonExams = exams.filter { !$0.isPast && $0.daysUntil <= 14 }.sorted { $0.daysUntil < $1.daysUntil }
        if !soonExams.isEmpty {
            let examLines = soonExams.map { "\($0.name) in \($0.daysUntil) day\($0.daysUntil == 1 ? "" : "s")" }
            lines.append("Upcoming tests:\n" + examLines.joined(separator: "\n"))
        }

        return lines.joined(separator: "\n\n")
    }

    // MARK: - Tool execution
    // JarvisController isn't a View, so it fetches directly via FetchDescriptor
    // rather than @Query.

    private func executeTool(name: String, input: [String: Any]) async -> String {
        guard let modelContext else { return "Data unavailable." }
        switch name {
        case "get_news":
            return newsSummary(topicRaw: input["topic"] as? String ?? "all", context: modelContext)
        case "get_today_summary":
            return todaySummary(context: modelContext)
        case "toggle_habit":
            return toggleHabit(named: input["name"] as? String ?? "", context: modelContext)
        case "log_skill_session":
            return logSkillSession(named: input["name"] as? String ?? "", note: input["note"] as? String, context: modelContext)
        case "add_project_task":
            return addProjectTask(project: input["project"] as? String ?? "", title: input["title"] as? String ?? "", context: modelContext)
        case "get_github_repos":
            return await githubReposSummary()
        case "add_extracurricular":
            return addExtracurricular(
                title: input["title"] as? String ?? "",
                description: input["description"] as? String ?? "",
                category: input["category"] as? String,
                context: modelContext
            )
        case "draft_outreach_emails":
            return await draftOutreachEmails(
                subject: input["subject"] as? String ?? "",
                topic: input["topic"] as? String ?? "",
                recipientDescription: input["recipientDescription"] as? String ?? "",
                count: (input["count"] as? NSNumber)?.intValue ?? 1,
                context: modelContext
            )
        default:
            return "Unknown tool."
        }
    }

    private func addExtracurricular(title: String, description: String, category: String?, context: ModelContext) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return "No activity title given." }
        context.insert(Extracurricular(
            title: trimmedTitle,
            activityDescription: description.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            isAISuggested: true
        ))
        return "Added \"\(trimmedTitle)\" to Extracurriculars."
    }

    private func draftOutreachEmails(
        subject: String,
        topic: String,
        recipientDescription: String,
        count: Int,
        context: ModelContext
    ) async -> String {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubject.isEmpty else { return "No subject given." }
        let clampedCount = max(1, min(count, 20))

        let prompt = """
        Draft a concise, warm, genuine-sounding outreach email.
        Subject: \(trimmedSubject)
        Purpose: \(topic)
        Recipient: \(recipientDescription.isEmpty ? "unspecified" : recipientDescription)
        Write it so it can be sent to more than one person of that description without sounding mass-produced.
        """

        do {
            let body = try await AISettings.currentService.draft(prompt: prompt)
            guard !body.isEmpty else { return "The draft came back empty — try again." }
            for index in 0..<clampedCount {
                let label = clampedCount > 1 ? "\(recipientDescription.isEmpty ? "Recipient" : recipientDescription.capitalized) #\(index + 1)" : recipientDescription.capitalized
                context.insert(EmailDraft(recipientLabel: label, subject: trimmedSubject, body: body))
            }
            return "Saved \(clampedCount) draft\(clampedCount == 1 ? "" : "s") in Emails for you to review, add a recipient to, and send."
        } catch {
            return "Couldn't draft the email: \(error.localizedDescription)"
        }
    }

    private func githubReposSummary() async -> String {
        do {
            let repos = try await GitHubService.shared.fetchRepos()
            if repos.isEmpty { return "No repositories found." }
            return repos.prefix(10).map { repo in
                var line = "• \(repo.name)"
                if let language = repo.language { line += " (\(language))" }
                if let description = repo.description, !description.isEmpty { line += " — \(description)" }
                return line
            }.joined(separator: "\n")
        } catch {
            return error.localizedDescription
        }
    }

    private func newsSummary(topicRaw: String, context: ModelContext) -> String {
        let items = (try? context.fetch(
            FetchDescriptor<NewsItem>(sortBy: [SortDescriptor(\.publishedAt, order: .reverse)])
        )) ?? []
        let scoped: [NewsItem]
        if let topic = NewsTopic(rawValue: topicRaw) {
            scoped = items.filter { $0.topic == topic }
        } else {
            scoped = items
        }
        if scoped.isEmpty {
            return "No cached headlines for that topic yet — open the News tab to refresh."
        }
        return scoped.prefix(8).map { "• [\($0.source)] \($0.title)" }.joined(separator: "\n")
    }

    private func todaySummary(context: ModelContext) -> String {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        let today = Calendar.current.startOfDay(for: Date())
        let scheduled = habits.filter { $0.isScheduled(on: today) }
        let done = scheduled.filter { $0.isCompleted(on: today) }
        let momentum = scheduled.isEmpty ? 0 : Int(Double(done.count) / Double(scheduled.count) * 100)
        let lines = scheduled.map { habit in
            "- \(habit.name): \(habit.isCompleted(on: today) ? "done" : "not done") (streak \(habit.currentStreak))"
        }
        return "Momentum: \(momentum)% (\(done.count)/\(scheduled.count))\n" + lines.joined(separator: "\n")
    }

    private func toggleHabit(named name: String, context: ModelContext) -> String {
        guard !name.isEmpty else { return "No habit name given." }
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        guard let habit = habits.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) else {
            return "No habit found matching \"\(name)\"."
        }
        let today = Calendar.current.startOfDay(for: Date())
        if let existing = habit.completions.first(where: { Calendar.current.isDate($0.date, inSameDayAs: today) }) {
            context.delete(existing)
            return "Marked \"\(habit.name)\" as not done for today."
        } else {
            context.insert(Completion(date: today, habit: habit))
            return "Marked \"\(habit.name)\" as done for today."
        }
    }

    private func logSkillSession(named name: String, note: String?, context: ModelContext) -> String {
        guard !name.isEmpty else { return "No skill name given." }
        let skills = (try? context.fetch(FetchDescriptor<Skill>())) ?? []
        guard let skill = skills.first(where: { $0.name.localizedCaseInsensitiveContains(name) }) else {
            return "No skill found matching \"\(name)\"."
        }
        context.insert(SkillSession(date: .now, note: note, skill: skill))
        return "Logged a session for \"\(skill.name)\" (\(skill.sessions.count + 1)/\(skill.targetSessions))."
    }

    private func addProjectTask(project: String, title: String, context: ModelContext) -> String {
        guard !project.isEmpty else { return "No project name given." }
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        guard let proj = projects.first(where: { $0.name.localizedCaseInsensitiveContains(project) }) else {
            return "No project found matching \"\(project)\"."
        }
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return "Task title was empty." }
        context.insert(ProjectTask(title: trimmedTitle, sortIndex: proj.tasks.count, project: proj))
        return "Added task \"\(trimmedTitle)\" to \"\(proj.name)\"."
    }
}

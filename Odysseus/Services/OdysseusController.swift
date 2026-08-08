//
//  OdysseusController.swift
//  Odysseus
//
//  Shared, app-wide voice assistant state. Lives above the NavigationStack
//  (mounted once in RootView) so it keeps listening no matter which screen
//  is on-screen — this is not a per-view feature.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class OdysseusController: NSObject, ObservableObject {
    static let shared = OdysseusController()

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
    /// The chat thread new messages attach to — persisted so relaunching the
    /// app resumes the same conversation instead of losing track of it.
    @Published var activeSessionID: String? {
        didSet { UserDefaults.standard.set(activeSessionID, forKey: Self.activeSessionKey) }
    }

    let voice = VoiceManager()

    private var modelContext: ModelContext?
    private var cancellables = Set<AnyCancellable>()
    private var silenceTimer: Timer?
    private static let activeSessionKey = "odysseus_active_session_id"

    private override init() {
        activeSessionID = UserDefaults.standard.string(forKey: Self.activeSessionKey)
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
        // 1.3s cut people off mid-thought; 3.0s felt laggy waiting to even
        // start processing. This is the balance between the two.
        silenceTimer = Timer.scheduledTimer(withTimeInterval: 1.7, repeats: false) { [weak self] _ in
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

    // MARK: - Chat sessions

    /// Resolves (or creates) the thread new messages attach to — works
    /// standalone even if the Copilot tab was never opened, since Odysseus
    /// voice mode can be the very first entry point.
    private func resolveActiveSession(context: ModelContext) -> ChatSession {
        if let activeSessionID {
            let descriptor = FetchDescriptor<ChatSession>(predicate: #Predicate { $0.id == activeSessionID })
            if let existing = try? context.fetch(descriptor).first {
                return existing
            }
        }
        let session = ChatSession()
        context.insert(session)
        activeSessionID = session.id
        return session
    }

    /// Starts a fresh thread and switches to it — old ones are never
    /// deleted, just no longer active.
    @discardableResult
    func startNewSession(context: ModelContext) -> ChatSession {
        let session = ChatSession()
        context.insert(session)
        activeSessionID = session.id
        return session
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
        let session = resolveActiveSession(context: modelContext)
        let userMessage = ChatMessage(role: "user", content: trimmed, imageData: imageData, session: session)
        modelContext.insert(userMessage)
        session.lastActivityAt = .now
        if session.title == "New Chat" {
            session.title = String(trimmed.prefix(40))
        }

        let sessionID = session.id
        let history = (try? modelContext.fetch(
            FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.session?.id == sessionID },
                sortBy: [SortDescriptor(\.createdAt)]
            )
        )) ?? []

        // Inserted empty and filled in live as tokens stream in — this is
        // what makes the reply appear word-by-word instead of all at once
        // after a long silent wait.
        let assistantMessage = ChatMessage(role: "assistant", content: "", session: session)
        modelContext.insert(assistantMessage)

        do {
            let reply = try await AISettings.currentService.send(
                history: history,
                onTextDelta: { delta in assistantMessage.content += delta }
            ) { [weak self] name, input in
                guard let self else { return "Unknown tool." }
                return await self.executeTool(name: name, input: input)
            }
            // Authoritative final text wins over whatever streamed in — covers
            // any preamble text from an intermediate tool-deciding turn.
            assistantMessage.content = reply

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
            modelContext.delete(assistantMessage)
            statusMessage = error.localizedDescription
            status = .idle
            // beginListening() resets statusMessage to nil immediately — call
            // it right after setting an error and the error is wiped before
            // it can ever be read. Give it a few seconds on screen first.
            if isActive {
                Task {
                    try? await Task.sleep(nanoseconds: 4_000_000_000)
                    guard self.isActive, self.status == .idle else { return }
                    self.beginListening()
                }
            }
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
        let foodEntries = ((try? modelContext.fetch(FetchDescriptor<FoodEntry>())) ?? [])
            .filter { Calendar.current.isDate($0.date, inSameDayAs: today) }
        if !foodEntries.isEmpty {
            let totalCalories = foodEntries.compactMap { $0.calories }.reduce(0, +)
            let totalProtein = foodEntries.compactMap { $0.proteinGrams }.reduce(0, +)
            lines.append("Food logged today: \(foodEntries.count) entries, \(totalCalories) cal, \(Int(totalProtein))g protein so far.")
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
    // OdysseusController isn't a View, so it fetches directly via FetchDescriptor
    // rather than @Query.

    private func executeTool(name: String, input: [String: Any]) async -> String {
        guard let modelContext else { return "Data unavailable." }
        switch name {
        case "get_news":
            return newsSummary(topicRaw: input["topic"] as? String ?? "all", context: modelContext)
        case "get_today_summary":
            return todaySummary(context: modelContext)
        case "log_skill_session":
            return logSkillSession(named: input["name"] as? String ?? "", note: input["note"] as? String, context: modelContext)
        case "add_project_task":
            return addProjectTask(project: input["project"] as? String ?? "", title: input["title"] as? String ?? "", context: modelContext)
        case "edit_project_task":
            return editProjectTask(
                project: input["project"] as? String ?? "",
                query: input["query"] as? String ?? "",
                newTitle: input["new_title"] as? String,
                markDone: input["mark_done"] as? Bool,
                context: modelContext
            )
        case "delete_project_task":
            return deleteProjectTask(
                project: input["project"] as? String ?? "",
                query: input["query"] as? String ?? "",
                confirmed: input["confirmed"] as? Bool ?? false,
                context: modelContext
            )
        case "add_assignment":
            return addAssignment(
                title: input["title"] as? String ?? "",
                dueDateString: input["due_date"] as? String,
                dueTimeString: input["due_time"] as? String,
                notes: input["notes"] as? String,
                context: modelContext
            )
        case "edit_assignment":
            return editAssignment(
                query: input["query"] as? String ?? "",
                newTitle: input["new_title"] as? String,
                newDueDateString: input["new_due_date"] as? String,
                newDueTimeString: input["new_due_time"] as? String,
                markDone: input["mark_done"] as? Bool,
                context: modelContext
            )
        case "get_school_material":
            return getSchoolMaterial(
                subject: input["subject"] as? String ?? "",
                query: input["query"] as? String,
                context: modelContext
            )
        case "delete_assignment":
            return deleteAssignment(
                query: input["query"] as? String ?? "",
                confirmed: input["confirmed"] as? Bool ?? false,
                context: modelContext
            )
        case "add_exam":
            return addExam(
                name: input["name"] as? String ?? "",
                examDateString: input["exam_date"] as? String,
                category: input["category"] as? String,
                className: input["class"] as? String,
                context: modelContext
            )
        case "edit_exam":
            return editExam(
                query: input["query"] as? String ?? "",
                newName: input["new_name"] as? String,
                newExamDateString: input["new_exam_date"] as? String,
                newClassName: input["new_class"] as? String,
                context: modelContext
            )
        case "set_project_target_date":
            return setProjectTargetDate(
                project: input["project"] as? String ?? "",
                targetDateString: input["target_date"] as? String,
                context: modelContext
            )
        case "delete_exam":
            return deleteExam(
                query: input["query"] as? String ?? "",
                confirmed: input["confirmed"] as? Bool ?? false,
                context: modelContext
            )
        case "edit_workout_entry":
            return editWorkoutEntry(
                query: input["query"] as? String ?? "",
                newNote: input["new_note"] as? String,
                newCaloriesBurned: input["new_calories_burned"] as? Int,
                context: modelContext
            )
        case "delete_workout_entry":
            return deleteWorkoutEntry(
                query: input["query"] as? String ?? "",
                confirmed: input["confirmed"] as? Bool ?? false,
                context: modelContext
            )
        case "edit_food_entry":
            return editFoodEntry(
                query: input["query"] as? String ?? "",
                newNote: input["new_note"] as? String,
                newCalories: input["new_calories"] as? Int,
                context: modelContext
            )
        case "delete_food_entry":
            return deleteFoodEntry(
                query: input["query"] as? String ?? "",
                confirmed: input["confirmed"] as? Bool ?? false,
                context: modelContext
            )
        case "get_github_repos":
            return await githubReposSummary()
        case "add_extracurricular":
            return addExtracurricular(
                title: input["title"] as? String ?? "",
                description: input["description"] as? String ?? "",
                category: input["category"] as? String,
                context: modelContext
            )
        case "edit_extracurricular":
            return editExtracurricular(
                query: input["query"] as? String ?? "",
                newTitle: input["new_title"] as? String,
                newDescription: input["new_description"] as? String,
                newCategory: input["new_category"] as? String,
                context: modelContext
            )
        case "delete_extracurricular":
            return deleteExtracurricular(
                query: input["query"] as? String ?? "",
                confirmed: input["confirmed"] as? Bool ?? false,
                context: modelContext
            )
        case "edit_skill":
            return editSkill(
                query: input["query"] as? String ?? "",
                newName: input["new_name"] as? String,
                newDescription: input["new_description"] as? String,
                newTargetSessions: input["new_target_sessions"] as? Int,
                context: modelContext
            )
        case "delete_skill":
            return deleteSkill(
                query: input["query"] as? String ?? "",
                confirmed: input["confirmed"] as? Bool ?? false,
                context: modelContext
            )
        case "draft_outreach_emails":
            return await draftOutreachEmails(
                subject: input["subject"] as? String ?? "",
                topic: input["topic"] as? String ?? "",
                recipients: input["recipients"] as? [[String: Any]] ?? [],
                context: modelContext
            )
        case "remember_fact":
            return rememberFact(input["fact"] as? String ?? "", context: modelContext)
        case "forget_fact":
            return forgetFact(
                matching: input["query"] as? String ?? "",
                confirmed: input["confirmed"] as? Bool ?? false,
                context: modelContext
            )
        default:
            return "Unknown tool."
        }
    }

    private func rememberFact(_ fact: String, context: ModelContext) -> String {
        let trimmed = fact.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "No fact given." }
        context.insert(MemoryEntry(content: trimmed, isAISaved: true))
        MemoryStore.rebuild(context: context)
        return "Remembered: \(trimmed)"
    }

    private func forgetFact(matching query: String, confirmed: Bool, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No fact to forget was given." }
        let entries = (try? context.fetch(FetchDescriptor<MemoryEntry>())) ?? []
        let matches = entries.filter { $0.content.localizedCaseInsensitiveContains(query) }
        guard !matches.isEmpty else { return "No remembered fact matching \"\(query)\"." }
        guard confirmed else {
            let preview = matches.map { "- \($0.content)" }.joined(separator: "\n")
            return "Found \(matches.count) matching fact\(matches.count == 1 ? "" : "s"):\n\(preview)\nConfirm you want these forgotten before I delete them."
        }
        for entry in matches { context.delete(entry) }
        MemoryStore.rebuild(context: context)
        return "Forgot \(matches.count) matching fact\(matches.count == 1 ? "" : "s")."
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

    private func findExtracurricular(matching query: String, context: ModelContext) -> Extracurricular? {
        let items = (try? context.fetch(FetchDescriptor<Extracurricular>())) ?? []
        return items.first { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func editExtracurricular(
        query: String,
        newTitle: String?,
        newDescription: String?,
        newCategory: String?,
        context: ModelContext
    ) -> String {
        guard !query.isEmpty else { return "No activity specified to edit." }
        guard let match = findExtracurricular(matching: query, context: context) else {
            return "No activity found matching \"\(query)\"."
        }
        if let newTitle, !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            match.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let newDescription {
            match.activityDescription = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let newCategory {
            match.category = newCategory.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return "Updated \"\(match.title)\"."
    }

    private func deleteExtracurricular(query: String, confirmed: Bool, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No activity specified to delete." }
        guard let match = findExtracurricular(matching: query, context: context) else {
            return "No activity found matching \"\(query)\"."
        }
        guard confirmed else {
            return "Found \"\(match.title)\" — confirm you want it deleted before I remove it."
        }
        let title = match.title
        context.delete(match)
        return "Deleted \"\(title)\"."
    }

    private func draftOutreachEmails(
        subject: String,
        topic: String,
        recipients: [[String: Any]],
        context: ModelContext
    ) async -> String {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubject.isEmpty else { return "No subject given." }
        let entries = recipients.isEmpty ? [["label": "Recipient"]] : recipients
        let clamped = Array(entries.prefix(20))

        let prompt = """
        Draft a concise, warm, genuine-sounding outreach email.
        Subject: \(trimmedSubject)
        Purpose: \(topic)
        Write it so it can be sent to more than one person without sounding mass-produced.
        """

        do {
            let body = try await AISettings.currentService.draft(prompt: prompt)
            guard !body.isEmpty else { return "The draft came back empty — try again." }
            var foundCount = 0
            for entry in clamped {
                let label = (entry["label"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "Recipient"
                let email = (entry["email"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                if !email.isEmpty { foundCount += 1 }
                context.insert(EmailDraft(recipientLabel: label, to: email, subject: trimmedSubject, body: body))
            }
            let addressedNote = foundCount == 0 ? " No real contact emails were found, so you'll need to fill those in." : " \(foundCount) of them already have a real address filled in from search."
            return "Saved \(clamped.count) draft\(clamped.count == 1 ? "" : "s") in Emails for you to review and send.\(addressedNote)"
        } catch {
            return "Couldn't draft the email: \(error.localizedDescription)"
        }
    }

    /// Recalls repos across every connected GitHub account (School, Personal,
    /// etc), not just whichever one is active in the GitHub tab's UI.
    private func githubReposSummary() async -> String {
        let accounts = GitHubAccountStore.accounts
        guard !accounts.isEmpty else { return "No GitHub account connected — add one in Settings → GitHub." }

        var lines: [String] = []
        for account in accounts {
            do {
                let repos = try await GitHubService.shared.fetchRepos(accountID: account.id)
                guard !repos.isEmpty else { continue }
                let accountLines = repos.prefix(10).map { repo -> String in
                    var line = "• \(repo.name)"
                    if let language = repo.language { line += " (\(language))" }
                    if let description = repo.description, !description.isEmpty { line += " — \(description)" }
                    return line
                }
                lines.append("\(account.name):\n" + accountLines.joined(separator: "\n"))
            } catch {
                continue
            }
        }
        return lines.isEmpty ? "No repositories found." : lines.joined(separator: "\n\n")
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

    /// Today's checklist — assignments and project tasks due today or
    /// overdue, same scope TodayView shows. No habit-streak concept.
    private func todaySummary(context: ModelContext) -> String {
        let today = Calendar.current.startOfDay(for: .now)
        let assignments = ((try? context.fetch(FetchDescriptor<Assignment>())) ?? []).filter { assignment in
            guard let due = assignment.dueDate else { return false }
            let dueDay = Calendar.current.startOfDay(for: due)
            return dueDay <= today && (dueDay == today || !assignment.isDone)
        }
        let tasks = ((try? context.fetch(FetchDescriptor<ProjectTask>())) ?? []).filter { task in
            guard let due = task.dueDate else { return false }
            let dueDay = Calendar.current.startOfDay(for: due)
            return dueDay <= today && (dueDay == today || !task.isDone)
        }
        let total = assignments.count + tasks.count
        let done = assignments.filter { $0.isDone }.count + tasks.filter { $0.isDone }.count
        guard total > 0 else { return "Nothing due today." }
        let assignmentLines = assignments.map { "- \($0.title): \($0.isDone ? "done" : "not done")" }
        let taskLines = tasks.map { "- \($0.title): \($0.isDone ? "done" : "not done")" }
        return "Today: \(done)/\(total) done\n" + (assignmentLines + taskLines).joined(separator: "\n")
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

    private func editSkill(query: String, newName: String?, newDescription: String?, newTargetSessions: Int?, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No skill specified to edit." }
        let skills = (try? context.fetch(FetchDescriptor<Skill>())) ?? []
        guard let skill = skills.first(where: { $0.name.localizedCaseInsensitiveContains(query) }) else {
            return "No skill found matching \"\(query)\"."
        }
        if let newName, !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            skill.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let newDescription {
            skill.skillDescription = newDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let newTargetSessions, newTargetSessions > 0 {
            skill.targetSessions = newTargetSessions
        }
        return "Updated \"\(skill.name)\"."
    }

    private func deleteSkill(query: String, confirmed: Bool, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No skill specified to delete." }
        let skills = (try? context.fetch(FetchDescriptor<Skill>())) ?? []
        guard let skill = skills.first(where: { $0.name.localizedCaseInsensitiveContains(query) }) else {
            return "No skill found matching \"\(query)\"."
        }
        guard confirmed else {
            return "Found \"\(skill.name)\" (\(skill.sessions.count) logged sessions) — confirm you want it deleted before I remove it."
        }
        let name = skill.name
        context.delete(skill)
        return "Deleted \"\(name)\"."
    }

    /// Sets (or clears, with an empty date) the whole project's target
    /// completion date — separate from any individual task's due date. This
    /// is what makes a passion/research project itself show up on Calendar,
    /// the same way an assignment or exam does.
    private func setProjectTargetDate(project: String, targetDateString: String?, context: ModelContext) -> String {
        guard !project.isEmpty else { return "No project name given." }
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        guard let proj = projects.first(where: { $0.name.localizedCaseInsensitiveContains(project) }) else {
            return "No project found matching \"\(project)\"."
        }
        guard let targetDateString, !targetDateString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            proj.targetDate = nil
            return "Cleared the target date for \"\(proj.name)\"."
        }
        guard let date = Self.isoDateFormatter.date(from: targetDateString) else {
            return "Need a valid date (yyyy-MM-dd)."
        }
        proj.targetDate = date
        return "\"\(proj.name)\" is now on the Calendar, due \(date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))."
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

    private func findProjectTask(project: String, query: String, context: ModelContext) -> ProjectTask? {
        let projects = (try? context.fetch(FetchDescriptor<Project>())) ?? []
        guard let proj = projects.first(where: { $0.name.localizedCaseInsensitiveContains(project) }) else { return nil }
        return proj.tasks.first { $0.title.localizedCaseInsensitiveContains(query) }
    }

    private func editProjectTask(project: String, query: String, newTitle: String?, markDone: Bool?, context: ModelContext) -> String {
        guard !project.isEmpty, !query.isEmpty else { return "Need both a project and which task to edit." }
        guard let task = findProjectTask(project: project, query: query, context: context) else {
            return "No task found matching \"\(query)\" in \"\(project)\"."
        }
        if let newTitle, !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            task.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let markDone {
            task.isDone = markDone
        }
        return "Updated \"\(task.title)\"."
    }

    private func deleteProjectTask(project: String, query: String, confirmed: Bool, context: ModelContext) -> String {
        guard !project.isEmpty, !query.isEmpty else { return "Need both a project and which task to delete." }
        guard let task = findProjectTask(project: project, query: query, context: context) else {
            return "No task found matching \"\(query)\" in \"\(project)\"."
        }
        guard confirmed else {
            return "Found \"\(task.title)\" in \"\(project)\" — confirm you want it deleted before I remove it."
        }
        let title = task.title
        context.delete(task)
        return "Deleted \"\(title)\"."
    }

    // MARK: - Assignments & exams (Calendar/School)

    private static let isoDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let isoTimeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        return formatter
    }()

    /// Combines a yyyy-MM-dd date with an optional HH:mm time of day into one
    /// Date — this is what lets Copilot put something on the calendar "at
    /// 3pm" instead of only ever landing at midnight. A date with no time
    /// given stays at midnight, same as picking a day in the date-only UI.
    private func combinedDate(dateString: String?, timeString: String?) -> Date? {
        guard let dateString, let day = Self.isoDateFormatter.date(from: dateString) else { return nil }
        guard let timeString, let time = Self.isoTimeFormatter.date(from: timeString) else { return day }
        var comps = Calendar.current.dateComponents([.year, .month, .day], from: day)
        let timeComps = Calendar.current.dateComponents([.hour, .minute], from: time)
        comps.hour = timeComps.hour
        comps.minute = timeComps.minute
        return Calendar.current.date(from: comps) ?? day
    }

    /// Pulls up whatever's been saved under a School subject/topic: freeform
    /// Notes and imported DocNotes (Google Docs/Notability) attached via
    /// `NoteContext.topic`, plus that topic's assignments. `subject` matches
    /// either a SchoolClass name (e.g. "AP Chemistry", pulling every topic
    /// under it) or a specific Topic name (e.g. "Recursion") directly.
    private func getSchoolMaterial(subject: String, query: String?, context: ModelContext) -> String {
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedSubject.isEmpty else { return "No subject or topic given." }

        let classes = (try? context.fetch(FetchDescriptor<SchoolClass>())) ?? []
        let allTopics = (try? context.fetch(FetchDescriptor<Topic>())) ?? []

        let matchedTopics: [Topic]
        if let matchedClass = classes.first(where: { $0.name.localizedCaseInsensitiveContains(trimmedSubject) }) {
            matchedTopics = matchedClass.topics
        } else {
            matchedTopics = allTopics.filter { $0.name.localizedCaseInsensitiveContains(trimmedSubject) }
        }
        guard !matchedTopics.isEmpty else {
            return "No class or topic found matching \"\(trimmedSubject)\"."
        }
        let topicNames = Dictionary(uniqueKeysWithValues: matchedTopics.map { ($0.id, $0.name) })
        let topicIDs = Set(topicNames.keys)

        var notes = ((try? context.fetch(FetchDescriptor<Note>())) ?? []).filter { note in
            note.contextTypeRaw == "topic" && topicIDs.contains(note.contextID ?? "")
        }
        var docNotes = ((try? context.fetch(FetchDescriptor<DocNote>())) ?? []).filter { doc in
            doc.contextTypeRaw == "topic" && topicIDs.contains(doc.contextID ?? "")
        }

        if let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            notes = notes.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.content.localizedCaseInsensitiveContains(query) }
            docNotes = docNotes.filter { $0.title.localizedCaseInsensitiveContains(query) || $0.content.localizedCaseInsensitiveContains(query) }
        }

        guard !notes.isEmpty || !docNotes.isEmpty else {
            let scopeNote = query.map { " matching \"\($0)\"" } ?? ""
            return "No material found for \"\(trimmedSubject)\"\(scopeNote) — add notes or import docs under that topic in School."
        }

        func excerpt(_ text: String) -> String {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.count > 200 else { return trimmed }
            return String(trimmed.prefix(200)) + "…"
        }

        var lines: [String] = []
        for note in notes.sorted(by: { $0.updatedAt > $1.updatedAt }) {
            let topicName = topicNames[note.contextID ?? ""] ?? "Untitled topic"
            let body = excerpt(note.content)
            lines.append("• [\(topicName)] \(note.title)" + (body.isEmpty ? "" : " — \(body)"))
        }
        for doc in docNotes.sorted(by: { $0.modifiedAt > $1.modifiedAt }) {
            let topicName = topicNames[doc.contextID ?? ""] ?? "Untitled topic"
            lines.append("• [\(topicName)] \(doc.title) (\(doc.source.label)) — \(excerpt(doc.excerpt.isEmpty ? doc.content : doc.excerpt))")
        }
        return lines.joined(separator: "\n")
    }

    private func addAssignment(title: String, dueDateString: String?, dueTimeString: String?, notes: String?, context: ModelContext) -> String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return "No assignment title given." }
        let dueDate = combinedDate(dateString: dueDateString, timeString: dueTimeString)
        let assignment = Assignment(title: trimmedTitle, dueDate: dueDate, notes: notes, remindersOn: dueDate != nil)
        context.insert(assignment)
        if dueDate != nil {
            NotificationManager.shared.sync(assignment: assignment)
        }
        let dateNote = dueDate.map { date -> String in
            let hasTime = dueTimeString != nil && !(dueTimeString?.isEmpty ?? true)
            let style: Date.FormatStyle = hasTime
                ? .dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()
                : .dateTime.weekday(.wide).month(.abbreviated).day()
            return " due \(date.formatted(style))"
        } ?? ""
        return "Added assignment \"\(trimmedTitle)\"\(dateNote)."
    }

    private func editAssignment(query: String, newTitle: String?, newDueDateString: String?, newDueTimeString: String?, markDone: Bool?, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No assignment specified to edit." }
        let assignments = (try? context.fetch(FetchDescriptor<Assignment>())) ?? []
        guard let assignment = assignments.first(where: { $0.title.localizedCaseInsensitiveContains(query) }) else {
            return "No assignment found matching \"\(query)\"."
        }
        if let newTitle, !newTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            assignment.title = newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if newDueDateString != nil || newDueTimeString != nil {
            // Re-anchor on the existing due date's day when only a new time is
            // given, so "move that to 5pm" doesn't require repeating the date.
            let fallbackDateString = assignment.dueDate.map { Self.isoDateFormatter.string(from: $0) }
            if let newDate = combinedDate(dateString: newDueDateString ?? fallbackDateString, timeString: newDueTimeString) {
                assignment.dueDate = newDate
            }
        }
        if let markDone {
            assignment.isDone = markDone
        }
        NotificationManager.shared.sync(assignment: assignment)
        return "Updated \"\(assignment.title)\"."
    }

    private func deleteAssignment(query: String, confirmed: Bool, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No assignment specified to delete." }
        let assignments = (try? context.fetch(FetchDescriptor<Assignment>())) ?? []
        guard let assignment = assignments.first(where: { $0.title.localizedCaseInsensitiveContains(query) }) else {
            return "No assignment found matching \"\(query)\"."
        }
        guard confirmed else {
            return "Found \"\(assignment.title)\" — confirm you want it deleted before I remove it."
        }
        let title = assignment.title
        NotificationManager.shared.cancelOneOff(identifier: "assignment-\(assignment.id)")
        context.delete(assignment)
        return "Deleted \"\(title)\"."
    }

    private func findSchoolClass(matching name: String, context: ModelContext) -> SchoolClass? {
        let classes = (try? context.fetch(FetchDescriptor<SchoolClass>())) ?? []
        return classes.first { $0.name.localizedCaseInsensitiveContains(name) }
    }

    private func addExam(name: String, examDateString: String?, category: String?, className: String?, context: ModelContext) -> String {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return "No exam name given." }
        guard let dateString = examDateString, let examDate = Self.isoDateFormatter.date(from: dateString) else {
            return "Need a valid exam date (yyyy-MM-dd)."
        }
        let resolvedCategory = category.flatMap { ExamCategory(rawValue: $0) } ?? .marchExams
        // Linking to a class is what makes this exam also show up on that
        // class's own page — not just Calendar/School exams.
        let matchedClass = className.flatMap { findSchoolClass(matching: $0, context: context) }
        context.insert(Exam(name: trimmedName, examDate: examDate, schoolClass: matchedClass, category: resolvedCategory))
        let classNote = matchedClass.map { " under \($0.name)" } ?? ""
        return "Added exam \"\(trimmedName)\"\(classNote) on \(examDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))."
    }

    private func editExam(query: String, newName: String?, newExamDateString: String?, newClassName: String?, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No exam specified to edit." }
        let exams = (try? context.fetch(FetchDescriptor<Exam>())) ?? []
        guard let exam = exams.first(where: { $0.name.localizedCaseInsensitiveContains(query) }) else {
            return "No exam found matching \"\(query)\"."
        }
        if let newName, !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            exam.name = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let newExamDateString, let newDate = Self.isoDateFormatter.date(from: newExamDateString) {
            exam.examDate = newDate
        }
        if let newClassName {
            let trimmed = newClassName.trimmingCharacters(in: .whitespacesAndNewlines)
            exam.schoolClass = trimmed.isEmpty ? nil : findSchoolClass(matching: trimmed, context: context)
        }
        return "Updated \"\(exam.name)\"."
    }

    private func deleteExam(query: String, confirmed: Bool, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No exam specified to delete." }
        let exams = (try? context.fetch(FetchDescriptor<Exam>())) ?? []
        guard let exam = exams.first(where: { $0.name.localizedCaseInsensitiveContains(query) }) else {
            return "No exam found matching \"\(query)\"."
        }
        guard confirmed else {
            return "Found \"\(exam.name)\" — confirm you want it deleted before I remove it."
        }
        let name = exam.name
        context.delete(exam)
        return "Deleted \"\(name)\"."
    }

    // MARK: - Health (food & workout entries)

    private func editWorkoutEntry(query: String, newNote: String?, newCaloriesBurned: Int?, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No workout specified to edit." }
        let entries = (try? context.fetch(FetchDescriptor<WorkoutEntry>())) ?? []
        guard let entry = entries.first(where: { $0.note.localizedCaseInsensitiveContains(query) }) else {
            return "No logged workout found matching \"\(query)\"."
        }
        if let newNote, !newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry.note = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let newCaloriesBurned {
            entry.caloriesBurned = newCaloriesBurned
        }
        return "Updated the workout entry \"\(entry.note)\"."
    }

    private func deleteWorkoutEntry(query: String, confirmed: Bool, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No workout specified to delete." }
        let entries = (try? context.fetch(FetchDescriptor<WorkoutEntry>())) ?? []
        guard let entry = entries.first(where: { $0.note.localizedCaseInsensitiveContains(query) }) else {
            return "No logged workout found matching \"\(query)\"."
        }
        guard confirmed else {
            return "Found the workout entry \"\(entry.note)\" — confirm you want it deleted before I remove it."
        }
        let note = entry.note
        context.delete(entry)
        return "Deleted the workout entry \"\(note)\"."
    }

    private func editFoodEntry(query: String, newNote: String?, newCalories: Int?, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No food entry specified to edit." }
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        guard let entry = entries.first(where: { $0.note.localizedCaseInsensitiveContains(query) }) else {
            return "No logged food entry found matching \"\(query)\"."
        }
        if let newNote, !newNote.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            entry.note = newNote.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let newCalories {
            entry.calories = newCalories
        }
        return "Updated the food entry \"\(entry.note)\"."
    }

    private func deleteFoodEntry(query: String, confirmed: Bool, context: ModelContext) -> String {
        guard !query.isEmpty else { return "No food entry specified to delete." }
        let entries = (try? context.fetch(FetchDescriptor<FoodEntry>())) ?? []
        guard let entry = entries.first(where: { $0.note.localizedCaseInsensitiveContains(query) }) else {
            return "No logged food entry found matching \"\(query)\"."
        }
        guard confirmed else {
            return "Found the food entry \"\(entry.note)\" — confirm you want it deleted before I remove it."
        }
        let note = entry.note
        context.delete(entry)
        return "Deleted the food entry \"\(note)\"."
    }
}

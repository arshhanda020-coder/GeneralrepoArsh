//
//  ProjectDetailView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var newTaskTitle = ""
    @State private var showingEdit = false
    @State private var editingTask: ProjectTask?
    @State private var isEditingPlan = false
    @State private var planDraft = ""
    @State private var isGeneratingBreakdown = false
    @State private var breakdownError: String?

    @State private var gitStatus: BridgeGitStatus?
    @State private var gitStatusError: String?
    @State private var isCheckingGitStatus = false
    @State private var showingRunSheet = false
    @State private var showingAIHelper = false

    private var accentColor: Color { Color(hex: project.colorHex) }

    private var sortedTasks: [ProjectTask] {
        project.tasks.sorted { $0.sortIndex < $1.sortIndex }
    }

    /// Bridge runs made against this project's repo, most recent first —
    /// distinct from any legacy chat-completion AgentRuns (none exist for
    /// projects, but the filter keeps that boundary explicit).
    private var sortedAgentRuns: [AgentRun] {
        project.agentRuns.filter { $0.bridgeAgentKind != nil }.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        List {
            Section {
                header
                if !project.projectDescription.isEmpty {
                    Text(project.projectDescription)
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                }
                ProgressView(value: project.progress)
                    .tint(accentColor)
                if let targetDate = project.targetDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                        Text("Due \(targetDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))")
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
                }
                if let repoURL = project.repoURL {
                    Link(destination: repoURL) {
                        Label(project.repoURLString ?? repoURL.absoluteString, systemImage: "link")
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
            }
            .listRowBackground(Theme.card)

            Section("REPO") {
                repoSection
            }
            .listRowBackground(Theme.card)

            Section("PLAN") {
                planSection
            }
            .listRowBackground(Theme.card)

            Section("TASKS") {
                ForEach(sortedTasks) { task in
                    taskRow(task)
                }
                .onDelete(perform: deleteTasks)
                .onMove(perform: moveTasks)

                addTaskRow

                Button {
                    generateBreakdown()
                } label: {
                    Label(isGeneratingBreakdown ? "Generating…" : "Generate tasks from plan", systemImage: "sparkles")
                }
                .disabled(isGeneratingBreakdown || (project.planText ?? "").isEmpty)

                if let breakdownError {
                    Text(breakdownError).font(.caption).foregroundStyle(Theme.negative)
                }
            }
            .listRowBackground(Theme.card)

            Section("AI HELPER") {
                Button {
                    showingAIHelper = true
                } label: {
                    Label("Consult AI Helper", systemImage: "sparkles")
                }
                .foregroundStyle(accentColor)
            }
            .listRowBackground(Theme.card)

            Section("NOTES") {
                NotesSectionView(context: .project(project.id), accentColor: accentColor)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                    .padding(8)
            }
            .listRowBackground(Theme.card)

            if !sortedAgentRuns.isEmpty {
                Section("AGENT RUNS") {
                    ForEach(sortedAgentRuns) { run in
                        agentRunRow(run)
                    }
                }
                .listRowBackground(Theme.card)
            }
        }
        #if os(iOS)
        .listStyle(.insetGrouped)
        #else
        .listStyle(.plain)
        #endif
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(project.name)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            #if os(iOS)
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
            #endif
        }
        .sheet(isPresented: $showingEdit) {
            AddEditProjectView(project: project)
        }
        .sheet(item: $editingTask) { task in
            AddEditProjectTaskView(task: task)
        }
        .sheet(isPresented: $showingRunSheet) {
            ProjectAgentRunSheet(project: project)
        }
        .sheet(isPresented: $showingAIHelper) {
            ProjectAIHelperSheet(project: project)
        }
        .onAppear {
            if project.repoPath != nil, gitStatus == nil { checkGitStatus() }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(project.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("\(project.tasks.filter { $0.isDone }.count)/\(project.tasks.count) tasks")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            statusPill
        }
    }

    private var statusPill: some View {
        Text(project.status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(project.status.color.opacity(0.18))
            .foregroundStyle(project.status.color)
            .clipShape(Capsule())
    }

    // MARK: - Repo

    private var repoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let repoPath = project.repoPath, !repoPath.isEmpty {
                Text(repoPath)
                    .font(.system(.caption, design: .monospaced))
                    .foregroundStyle(Theme.primaryText)
                    .textSelection(.enabled)

                gitStatusRow

                HStack(spacing: 12) {
                    Button("Check Status") { checkGitStatus() }
                        .disabled(isCheckingGitStatus)
                    Button("Run Agent") { showingRunSheet = true }
                        .foregroundStyle(accentColor)
                }
                .font(.caption.weight(.semibold))
            } else {
                Text("No repo linked. Add a path from the ⋯ menu (Edit) to run Claude Code / Codex against this project's real codebase.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            }
        }
    }

    @ViewBuilder
    private var gitStatusRow: some View {
        if isCheckingGitStatus {
            HStack(spacing: 6) {
                ProgressView().scaleEffect(0.6)
                Text("Checking…").font(.caption2).foregroundStyle(Theme.dimText)
            }
        } else if let gitStatusError {
            Text(gitStatusError).font(.caption2).foregroundStyle(Theme.negative)
        } else if let gitStatus {
            if gitStatus.isRepo {
                HStack(spacing: 8) {
                    Label(gitStatus.branch ?? "detached", systemImage: "arrow.triangle.branch")
                    if gitStatus.dirty > 0 {
                        Label("\(gitStatus.dirty)", systemImage: "circle.fill")
                    }
                    if gitStatus.ahead > 0 {
                        Label("\(gitStatus.ahead)", systemImage: "arrow.up")
                    }
                    if gitStatus.behind > 0 {
                        Label("\(gitStatus.behind)", systemImage: "arrow.down")
                    }
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(gitStatus.dirty > 0 ? Theme.terminalAmber : Theme.terminalGreen)
            } else {
                Text("Not a git repo (or bridge unreachable).")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
        }
    }

    private func checkGitStatus() {
        guard let repoPath = project.repoPath, !repoPath.isEmpty else { return }
        let bridgeURL = UserDefaults.standard.string(forKey: DevAgentKind.claudeCode.bridgeURLKey) ?? ""
        let token = KeychainService.shared.loadBridgeToken(kind: DevAgentKind.claudeCode.agentKey) ?? ""
        guard !bridgeURL.isEmpty, !token.isEmpty else {
            gitStatusError = "Set up the bridge under Subagents → Claude Code to see repo status."
            return
        }
        isCheckingGitStatus = true
        gitStatusError = nil
        Task {
            do {
                gitStatus = try await DevAgentBridgeClient.gitStatus(baseURL: bridgeURL, token: token, cwd: repoPath)
            } catch {
                gitStatusError = error.localizedDescription
            }
            isCheckingGitStatus = false
        }
    }

    // MARK: - Agent runs

    private func agentRunRow(_ run: AgentRun) -> some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 6) {
                if let prompt = run.prompt, !prompt.isEmpty {
                    Text(prompt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.primaryText)
                }
                Text(run.ok ? run.output : (run.errorMessage ?? "Unknown error."))
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(run.ok ? Theme.dimText : Theme.negative)
                    .textSelection(.enabled)
            }
            .padding(.top, 4)
        } label: {
            HStack(spacing: 8) {
                Circle()
                    .fill(run.ok ? Theme.terminalGreen : Theme.negative)
                    .frame(width: 6, height: 6)
                VStack(alignment: .leading, spacing: 1) {
                    Text(run.bridgeAgentKind == DevAgentKind.codex.agentKey ? "Codex" : "Claude Code")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text(run.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                if let costUSD = run.costUSD {
                    Text(String(format: "$%.3f", costUSD))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.dimText)
                }
            }
        }
    }

    // MARK: - Plan

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if isEditingPlan {
                TextField("What's the plan for this project?", text: $planDraft, axis: .vertical)
                    .lineLimit(4...12)
                HStack {
                    Button("Cancel") {
                        isEditingPlan = false
                    }
                    .foregroundStyle(Theme.dimText)
                    Spacer()
                    Button("Save Plan") {
                        project.planText = planDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        isEditingPlan = false
                    }
                    .foregroundStyle(accentColor)
                }
                .font(.caption.weight(.semibold))
            } else if let plan = project.planText, !plan.isEmpty {
                Text(plan)
                    .font(.subheadline)
                    .foregroundStyle(Theme.primaryText)
                Button("Edit plan") {
                    planDraft = plan
                    isEditingPlan = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
            } else {
                Text("No plan yet. Add one and Odysseus/Copilot can break it into dated tasks and remind you as they come due.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                Button("Add plan") {
                    planDraft = ""
                    isEditingPlan = true
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(accentColor)
            }
        }
    }

    private func taskRow(_ task: ProjectTask) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    task.isDone.toggle()
                }
                NotificationManager.shared.sync(projectTask: task)
                if task.isDone { NotificationManager.shared.notifyTaskCompleted(title: task.title) }
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? accentColor : Theme.dimText)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(task.title)
                    .foregroundStyle(task.isDone ? Theme.dimText : Theme.primaryText)
                    .strikethrough(task.isDone)
                if let due = task.dueDate {
                    HStack(spacing: 3) {
                        if task.remindersOn {
                            Image(systemName: "bell.fill").font(.caption2)
                        }
                        Text(due.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.caption2)
                    }
                    .foregroundStyle(Theme.dimText)
                }
            }
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture { editingTask = task }
    }

    private var addTaskRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .foregroundStyle(Theme.dimText)
            TextField("Add task", text: $newTaskTitle)
                .foregroundStyle(Theme.primaryText)
                .onSubmit(addTask)
        }
    }

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let task = ProjectTask(title: trimmed, sortIndex: project.tasks.count, project: project)
        modelContext.insert(task)
        newTaskTitle = ""
    }

    private func deleteTasks(at offsets: IndexSet) {
        let items = sortedTasks
        for index in offsets {
            NotificationManager.shared.cancelReminders(projectTaskID: items[index].id)
            modelContext.delete(items[index])
        }
    }

    private func moveTasks(from source: IndexSet, to destination: Int) {
        var items = sortedTasks
        items.move(fromOffsets: source, toOffset: destination)
        for (index, task) in items.enumerated() {
            task.sortIndex = index
        }
    }

    // MARK: - AI breakdown

    private func generateBreakdown() {
        guard let plan = project.planText, !plan.isEmpty else { return }
        isGeneratingBreakdown = true
        breakdownError = nil
        let today = Date()
        let prompt = """
        Break this project plan into a short list of concrete, dated milestone tasks, starting from today (\(today.formatted(.dateTime.month(.wide).day().year()))).
        Plan: \(plan)
        Respond with ONLY the tasks, one per line, no markdown, in EXACTLY this format:
        TASK: <short task title> | DUE: <yyyy-MM-dd>
        """
        Task {
            do {
                let text = try await AISettings.currentService.draft(prompt: prompt)
                let drafts = Self.parseTasks(text)
                guard !drafts.isEmpty else {
                    breakdownError = "Couldn't parse a task list — try rephrasing the plan."
                    isGeneratingBreakdown = false
                    return
                }
                var nextIndex = project.tasks.count
                for draft in drafts {
                    let newTask = ProjectTask(title: draft.title, sortIndex: nextIndex, dueDate: draft.dueDate, remindersOn: draft.dueDate != nil, project: project)
                    modelContext.insert(newTask)
                    NotificationManager.shared.sync(projectTask: newTask)
                    nextIndex += 1
                }
            } catch {
                breakdownError = error.localizedDescription
            }
            isGeneratingBreakdown = false
        }
    }

    private static func parseTasks(_ text: String) -> [(title: String, dueDate: Date?)] {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        var results: [(title: String, dueDate: Date?)] = []
        for line in text.split(separator: "\n") {
            guard line.uppercased().hasPrefix("TASK:") else { continue }
            let body = line.dropFirst("TASK:".count)
            let parts = body.components(separatedBy: "| DUE:")
            let title = parts[0].trimmingCharacters(in: .whitespaces)
            guard !title.isEmpty else { continue }
            let dueDate = parts.count > 1 ? formatter.date(from: parts[1].trimmingCharacters(in: .whitespaces)) : nil
            results.append((title, dueDate))
        }
        return results
    }
}

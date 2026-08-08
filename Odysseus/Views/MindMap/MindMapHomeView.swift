//
//  MindMapHomeView.swift
//  Odysseus
//
//  Home screen: a plain, content-first list — a big title header like
//  Notes/Messages, a pinned "Today" summary card, and every section as a
//  flat list row (colored icon badge, title, count, chevron) with hairline
//  dividers, the way Notes/Reminders/Settings and iMessage's conversation
//  list actually look. No centerpiece artwork, no HUD readouts.
//

import SwiftUI
import SwiftData

struct MindMapHomeView: View {
    @EnvironmentObject private var odysseus: OdysseusController
    @Query(sort: \Skill.createdAt) private var skills: [Skill]
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \NewsItem.publishedAt) private var newsItems: [NewsItem]
    @Query private var assignments: [Assignment]
    @Query private var projectTasks: [ProjectTask]
    @Query private var exams: [Exam]
    @Query private var extracurriculars: [Extracurricular]
    @Query private var memories: [MemoryEntry]
    @Query private var researchEntries: [ResearchEntry]
    @Query private var agentDefinitions: [AgentDefinition]
    @Query private var obsidianNotes: [ObsidianNote]
    @Query private var docNotes: [DocNote]
    @Query private var aiToolItems: [AIToolItem]
    @Query(sort: \FoodEntry.date, order: .reverse) private var foodEntries: [FoodEntry]
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var workoutEntries: [WorkoutEntry]

    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var selectedSection: MindMapSection?
    /// Drives the cinematic zoom transition — the tapped row expands into
    /// the destination screen instead of a flat push.
    @Namespace private var sectionTransition

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    /// Today's checklist momentum — same items TodayView shows (assignments +
    /// project tasks due today or overdue), not a habit-streak concept.
    private var todayChecklistCounts: (done: Int, total: Int) {
        var done = 0
        var total = 0
        for assignment in assignments {
            guard let due = assignment.dueDate else { continue }
            let dueDay = Calendar.current.startOfDay(for: due)
            guard dueDay <= today, dueDay == today || !assignment.isDone else { continue }
            total += 1
            if assignment.isDone { done += 1 }
        }
        for task in projectTasks {
            guard let due = task.dueDate else { continue }
            let dueDay = Calendar.current.startOfDay(for: due)
            guard dueDay <= today, dueDay == today || !task.isDone else { continue }
            total += 1
            if task.isDone { done += 1 }
        }
        return (done, total)
    }
    private var momentum: Double {
        let counts = todayChecklistCounts
        return counts.total == 0 ? 0 : Double(counts.done) / Double(counts.total)
    }

    private var learnedSkills: Int { skills.filter { $0.isLearned }.count }
    private var projectTasksDone: Int { projects.flatMap { $0.tasks }.filter { $0.isDone }.count }
    private var projectTasksTotal: Int { projects.flatMap { $0.tasks }.count }

    private var healthLoggedToday: Int {
        foodEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.count
            + workoutEntries.filter { Calendar.current.isDate($0.date, inSameDayAs: today) }.count
    }

    private var pendingAssignments: Int { assignments.filter { !$0.isDone }.count }
    private var overdueCount: Int { assignments.filter { !$0.isDone && ($0.dueDate.map { $0 < today } ?? false) }.count }
    private var upcomingAgendaCount: Int {
        let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        let examCount = exams.filter { !$0.isPast && $0.examDate <= weekOut }.count
        let assignmentCount = assignments.filter { !$0.isDone && ($0.dueDate.map { $0 <= weekOut } ?? false) }.count
        return examCount + assignmentCount
    }
    private var innovationCount: Int { aiToolItems.filter { $0.category == .innovation }.count }

    /// Every section except Today, which gets its own pinned summary card.
    private var listedSections: [MindMapSection] { MindMapSection.allCases.filter { $0 != .today } }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 20) {
                header
                todayCard
                sectionsList
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
        .background(Theme.background.ignoresSafeArea())
        .safeAreaInset(edge: .bottom, spacing: 0) {
            NewsTickerView()
        }
        .navigationTitle("")
        .inlineNavigationTitle()
        .navigationDestination(item: $selectedSection) { section in
            destination(for: section)
                .zoomNavigationTransition(sourceID: section, in: sectionTransition)
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    // MARK: - Header

    /// Big bold title like Notes' "Notes" / Messages' "Messages", with the
    /// same settings/search icon cluster the HUD header had, just plain.
    private var header: some View {
        HStack(alignment: .center) {
            Button {
                odysseus.activate()
            } label: {
                HStack(spacing: 7) {
                    Text("Odysseus")
                        .font(.largeTitle.weight(.bold))
                        .foregroundStyle(Theme.primaryText)
                    if odysseus.isActive {
                        Circle()
                            .fill(Theme.negative)
                            .frame(width: 7, height: 7)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(odysseus.isActive ? "Odysseus, listening" : "Odysseus")

            Spacer()

            HStack(spacing: 20) {
                Button { showingSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                }
                .accessibilityLabel("Search everything")

                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
                .accessibilityLabel("Settings")
            }
            .font(.title3)
            .foregroundStyle(Theme.accent)
            .buttonStyle(.plain)
        }
    }

    // MARK: - Today card

    private var todaySubtitle: String {
        let counts = todayChecklistCounts
        if counts.total == 0 { return "Nothing due" }
        return "\(counts.done) of \(counts.total) done"
    }

    /// Pinned summary card — the equivalent of Reminders' smart "Today" list
    /// sitting above your own lists.
    private var todayCard: some View {
        Button {
            selectedSection = .today
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(Theme.cardBorder, lineWidth: 3)
                    Circle()
                        .trim(from: 0, to: max(momentum, 0.001))
                        .stroke(Theme.terminalGreen, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                }
                .frame(width: 32, height: 32)
                .opacity(todayChecklistCounts.total == 0 ? 0.35 : 1)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Today")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text(todaySubtitle)
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                }

                Spacer()

                if overdueCount > 0 {
                    Text("\(overdueCount)")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Theme.negative, in: Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.dimText.opacity(0.5))
            }
            .padding(14)
        }
        .buttonStyle(.plain)
        .glassPanel(cornerRadius: 14)
        .matchedTransitionSource(id: MindMapSection.today, in: sectionTransition)
    }

    // MARK: - Sections list

    /// The app's navigation — a plain grouped list, like Settings/Notes
    /// folders, instead of a dense instrumentation grid.
    private var sectionsList: some View {
        VStack(spacing: 0) {
            ForEach(Array(listedSections.enumerated()), id: \.element.id) { index, section in
                if index > 0 {
                    Divider()
                        .overlay(Theme.cardBorder)
                        .padding(.leading, 56)
                }
                sectionRow(section)
            }
        }
        .glassPanel(cornerRadius: 14)
    }

    private func sectionRow(_ section: MindMapSection) -> some View {
        Button {
            selectedSection = section
        } label: {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(section.accentColor)
                    .frame(width: 30, height: 30)
                    .overlay(
                        Image(systemName: section.symbolName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                    )

                Text(section.title)
                    .font(.body)
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)

                Spacer()

                if let value = badge(for: section) {
                    Text(value)
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                }

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.dimText.opacity(0.5))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .matchedTransitionSource(id: section, in: sectionTransition)
    }

    @ViewBuilder
    private func destination(for section: MindMapSection) -> some View {
        switch section {
        case .today: TodayView()
        case .skills: SkillsView()
        case .projects: ProjectsView()
        case .news: NewsView()
        case .copilot: CopilotView()
        case .stats: StatsView()
        case .emails: EmailsView()
        case .aiIntegration: AIIntegrationView()
        case .github: GitHubView()
        case .school: SchoolView()
        case .health: HealthView()
        case .calendar: CalendarView()
        case .extracurriculars: ExtracurricularsView()
        case .memory: MemoryView()
        case .research: ResearchView()
        case .agents: AgentsView()
        case .claudeCode: DevAgentBridgeView(kind: .claudeCode)
        case .codex: DevAgentBridgeView(kind: .codex)
        case .obsidian: ObsidianView()
        case .notes: NotesView()
        }
    }

    private func badge(for section: MindMapSection) -> String? {
        switch section {
        case .today:
            let counts = todayChecklistCounts
            return counts.total == 0 ? nil : "\(counts.done)/\(counts.total)"
        case .skills:
            return skills.isEmpty ? nil : "\(learnedSkills)/\(skills.count)"
        case .projects:
            return projectTasksTotal == 0 ? nil : "\(projectTasksDone)/\(projectTasksTotal)"
        case .news:
            return newsItems.isEmpty ? nil : "\(newsItems.count)"
        case .copilot:
            return nil
        case .stats:
            return nil
        case .emails:
            return nil
        case .aiIntegration:
            return innovationCount == 0 ? nil : "\(innovationCount)"
        case .github:
            return nil
        case .school:
            return pendingAssignments == 0 ? nil : "\(pendingAssignments)"
        case .health:
            return healthLoggedToday == 0 ? nil : "\(healthLoggedToday)"
        case .calendar:
            return upcomingAgendaCount == 0 ? nil : "\(upcomingAgendaCount)"
        case .extracurriculars:
            return extracurriculars.isEmpty ? nil : "\(extracurriculars.count)"
        case .memory:
            return memories.isEmpty ? nil : "\(memories.count)"
        case .research:
            return researchEntries.isEmpty ? nil : "\(researchEntries.count)"
        case .agents:
            return agentDefinitions.isEmpty ? nil : "\(agentDefinitions.count)"
        case .claudeCode, .codex:
            return nil
        case .obsidian:
            return obsidianNotes.isEmpty ? nil : "\(obsidianNotes.count)"
        case .notes:
            return docNotes.isEmpty ? nil : "\(docNotes.count)"
        }
    }
}

#Preview {
    NavigationStack {
        MindMapHomeView()
    }
    .environmentObject(OdysseusController.shared)
    .modelContainer(
        for: [FoodEntry.self, WorkoutEntry.self, Skill.self, SkillSession.self, Project.self, ProjectTask.self, NewsItem.self],
        inMemory: true
    )
}

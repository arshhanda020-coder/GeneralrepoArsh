//
//  MindMapHomeView.swift
//  Odysseus
//
//  Home screen rebuilt as a unified HUD dashboard (not a ring of app icons)
//  modeled directly on a reference screenshot the user provided: a live
//  badge/header, the reactor as the dominant centerpiece, a notification
//  panel on the left, and the app's sections as a tappable status-list panel
//  on the right — everything centered around Odysseus rather than a grid.
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
    @Query private var aiToolItems: [AIToolItem]
    @Query(sort: \FoodEntry.date, order: .reverse) private var foodEntries: [FoodEntry]
    @Query(sort: \WorkoutEntry.date, order: .reverse) private var workoutEntries: [WorkoutEntry]

    @State private var showingSearch = false
    @State private var showingSettings = false
    @State private var selectedSection: MindMapSection?
    /// Drives the cinematic zoom transition — the tapped tile expands into
    /// the destination screen instead of a flat push, like selecting a
    /// module on a HUD instead of a plain iOS nav push.
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

    var body: some View {
        VStack(spacing: 0) {
            header

            GeometryReader { geo in
                let reactorSize = min(geo.size.width * 0.72, geo.size.height * 0.46, 320)

                VStack(spacing: 0) {
                    ArcReactorView(size: reactorSize, isActive: momentum >= 1)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 4)
                        .contentShape(Rectangle())
                        .onTapGesture { odysseus.activate() }
                        .accessibilityLabel("Odysseus")

                    HStack(spacing: 6) {
                        ForEach(statusRows) { row in
                            statusChip(row)
                        }
                    }
                    .padding(.top, 14)

                    ScrollView(showsIndicators: false) {
                        sectionsGrid
                            .padding(.top, 14)
                            .padding(.bottom, 12)
                    }
                }
                .padding(.horizontal, 16)
                .frame(width: geo.size.width, height: geo.size.height, alignment: .top)
            }
            .padding(.top, 6)
        }
        .background(ambientGlassBackdrop.ignoresSafeArea())
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

    // MARK: - Backdrop

    /// Soft, colored ambient light behind the whole screen — without this,
    /// the frosted glass panels have nothing but flat black to diffuse and
    /// just look like tinted rectangles. Real glass reads as glass when
    /// there's light bleeding through it.
    private var ambientGlassBackdrop: some View {
        ZStack {
            Theme.background
            RadialGradient(
                colors: [Theme.reactorGlow.opacity(0.22), .clear],
                center: UnitPoint(x: 0.5, y: 0.16), startRadius: 0, endRadius: 340
            )
            RadialGradient(
                colors: [Theme.nebulaWispB.opacity(0.14), .clear],
                center: UnitPoint(x: 0.85, y: 0.55), startRadius: 0, endRadius: 260
            )
            RadialGradient(
                colors: [Theme.nebulaWispC.opacity(0.12), .clear],
                center: UnitPoint(x: 0.1, y: 0.7), startRadius: 0, endRadius: 240
            )
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 8) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")

            Text("O.D.Y.S.S.E.U.S")
                .font(.system(size: 13, design: .monospaced).weight(.bold))
                .tracking(2)
                .foregroundStyle(Theme.reactorCore)

            Spacer(minLength: 8)

            liveBadge

            Button {
                showingSearch = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search everything")
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(odysseus.isActive ? Color(hex: "FF6B6B") : Theme.terminalGreen)
                .frame(width: 5, height: 5)
            Text(odysseus.isActive ? "LISTENING" : "STANDBY")
                .font(.system(size: 9, design: .monospaced).weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.dimText)
            Text("·")
                .foregroundStyle(Theme.dimText)
            Text(Self.timeFormatter.string(from: .now))
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(Theme.dimText)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassCapsule(
            tintOpacity: 0.5,
            borderColor: Theme.reactorGlow,
            borderOpacity: 0.4,
            glow: Theme.reactorGlow,
            glowRadius: 4
        )
    }

    // MARK: - Status chips

    private var statusRows: [HUDStatusRow] {
        [
            HUDStatusRow("TODAY", "\(Int(momentum * 100))%", isLive: momentum > 0),
            HUDStatusRow("OVERDUE", "\(overdueCount)", isLive: overdueCount > 0),
            HUDStatusRow("DUE 7D", "\(upcomingAgendaCount)", isLive: upcomingAgendaCount > 0),
            HUDStatusRow("AI FINDS", "\(innovationCount)", isLive: innovationCount > 0),
        ]
    }

    private func statusChip(_ row: HUDStatusRow) -> some View {
        VStack(spacing: 3) {
            Text(row.value)
                .font(.system(size: 15, design: .monospaced).weight(.bold))
                .foregroundStyle(row.isLive ? Theme.terminalGreen : Theme.dimText)
            Text(row.label)
                .font(.system(size: 8, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .glassPanel(cornerRadius: 6, tintOpacity: 0.55, borderColor: Theme.reactorGlow.opacity(0.3))
    }

    // MARK: - Sections grid

    /// The app's actual navigation now — living in a dense instrumentation
    /// grid below the reactor instead of a separate icon ring.
    private var sectionsGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
            ForEach(MindMapSection.allCases) { section in
                Button {
                    selectedSection = section
                } label: {
                    let value = badge(for: section)
                    HStack(spacing: 5) {
                        Circle()
                            .fill(value != nil ? Theme.terminalGreen : Theme.dimText.opacity(0.4))
                            .frame(width: 5, height: 5)
                        Text(section.title.uppercased())
                            .font(.system(size: 10, design: .monospaced).weight(.semibold))
                            .foregroundStyle(value != nil ? Theme.terminalGreen : Theme.primaryText)
                            .lineLimit(1)
                        Spacer(minLength: 4)
                        Text(value ?? "—")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(value != nil ? Theme.terminalGreen : Theme.dimText.opacity(0.6))
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 9)
                    .frame(maxWidth: .infinity)
                    .glassPanel(cornerRadius: 6, tintOpacity: 0.5, borderColor: Theme.reactorGlow.opacity(0.25))
                }
                .buttonStyle(.plain)
                .matchedTransitionSource(id: section, in: sectionTransition)
            }
        }
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
        case .emails:
            #if os(iOS)
            EmailsView()
            #else
            ComingSoonView(title: "Emails")
            #endif
        case .aiIntegration: AIIntegrationView()
        case .github: GitHubView()
        case .school: SchoolView()
        case .health:
            #if os(iOS)
            HealthView()
            #else
            ComingSoonView(title: "Health")
            #endif
        case .calendar: CalendarView()
        case .extracurriculars:
            #if os(iOS)
            ExtracurricularsView()
            #else
            ComingSoonView(title: "Extracurriculars")
            #endif
        case .memory: MemoryView()
        case .research: ResearchView()
        case .agents: AgentsView()
        case .claudeCode: DevAgentBridgeView(kind: .claudeCode)
        case .codex: DevAgentBridgeView(kind: .codex)
        case .obsidian: ObsidianView()
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
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
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

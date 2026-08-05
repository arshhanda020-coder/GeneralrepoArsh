//
//  MindMapHomeView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct MindMapHomeView: View {
    @EnvironmentObject private var jarvis: JarvisController
    @Query(sort: \Habit.createdAt) private var habits: [Habit]
    @Query(sort: \Skill.createdAt) private var skills: [Skill]
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query(sort: \NewsItem.publishedAt) private var newsItems: [NewsItem]
    @Query private var assignments: [Assignment]
    @Query private var exams: [Exam]
    @Query private var extracurriculars: [Extracurricular]
    @Query private var memories: [MemoryEntry]

    @State private var hasAppeared = false
    @State private var showingSearch = false
    @State private var showingSettings = false

    private let radius: CGFloat = 240
    private let nodeWidth: CGFloat = 84
    private let nodeHeight: CGFloat = 62

    private var mapSize: CGFloat { (radius + 96) * 2 }
    private var mapCenter: CGPoint { CGPoint(x: mapSize / 2, y: mapSize / 2) }

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var scheduledToday: [Habit] { habits.filter { $0.isScheduled(on: today) } }
    private var doneToday: Int { scheduledToday.filter { $0.isCompleted(on: today) }.count }
    private var momentum: Double {
        scheduledToday.isEmpty ? 0 : Double(doneToday) / Double(scheduledToday.count)
    }

    private var learnedSkills: Int { skills.filter { $0.isLearned }.count }
    private var projectTasksDone: Int { projects.flatMap { $0.tasks }.filter { $0.isDone }.count }
    private var projectTasksTotal: Int { projects.flatMap { $0.tasks }.count }

    private var healthHabits: [Habit] { habits.filter { $0.category == .meals || $0.category == .workouts } }
    private var healthLoggedToday: Int { healthHabits.filter { $0.isCompleted(on: today) }.count }

    private var pendingAssignments: Int { assignments.filter { !$0.isDone }.count }
    private var upcomingAgendaCount: Int {
        let weekOut = Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today
        let examCount = exams.filter { !$0.isPast && $0.examDate <= weekOut }.count
        let assignmentCount = assignments.filter { !$0.isDone && ($0.dueDate.map { $0 <= weekOut } ?? false) }.count
        return examCount + assignmentCount
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .padding(.top, 8)

            DailyQuoteView()
                .padding(.top, 12)
                .padding(.bottom, 4)

            GeometryReader { geo in
                // Fixed fit-scale, no pan/zoom — this stays still until enough
                // sections are added that a static layout no longer fits.
                let fitScale = min(geo.size.width / mapSize, geo.size.height / mapSize) * 0.5

                ZStack {
                    dotGridBackground

                    ForEach(Array(MindMapSection.allCases.enumerated()), id: \.element) { index, section in
                        connector(index: index, total: MindMapSection.allCases.count, section: section)
                    }

                    ForEach(Array(MindMapSection.allCases.enumerated()), id: \.element) { index, section in
                        let offset = nodeOffset(index: index, total: MindMapSection.allCases.count)
                        MindMapSectionNodeView(
                            section: section,
                            index: index,
                            badge: badge(for: section),
                            width: nodeWidth,
                            height: nodeHeight,
                            hasAppeared: hasAppeared
                        )
                        .position(x: mapCenter.x + offset.x, y: mapCenter.y + offset.y)
                    }

                    centerNode
                }
                .frame(width: mapSize, height: mapSize)
                .scaleEffect(fitScale)
                .position(x: geo.size.width / 2, y: geo.size.height / 2)
            }

            NewsTickerView()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("")
        .toolbar(.hidden, for: .navigationBar)
        .onAppear {
            guard !hasAppeared else { return }
            withAnimation(.spring(response: 0.6, dampingFraction: 0.72).delay(0.05)) {
                hasAppeared = true
            }
        }
        .sheet(isPresented: $showingSearch) {
            SearchView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }

    /// Everything lives in normal layout flow here — nothing floats over
    /// anything else, so there's no overlap to worry about.
    private var topBar: some View {
        HStack(spacing: 10) {
            Button {
                showingSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.body)
                    .foregroundStyle(Theme.dimText)
                    .frame(width: 38, height: 38)
                    .background(Theme.card)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Settings")

            Button {
                showingSearch = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Theme.dimText)
                    Text("Search everything")
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                    Spacer()
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
            }
            .buttonStyle(.plain)

            Button {
                jarvis.activate()
            } label: {
                ArcReactorView(size: 38, isActive: jarvis.isActive)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Jarvis")
        }
        .padding(.horizontal, 16)
    }

    private var dotGridBackground: some View {
        Canvas { context, size in
            let spacing: CGFloat = 22
            let dotSize: CGFloat = 1.6
            var y: CGFloat = spacing / 2
            while y < size.height {
                var x: CGFloat = spacing / 2
                while x < size.width {
                    let rect = CGRect(x: x - dotSize / 2, y: y - dotSize / 2, width: dotSize, height: dotSize)
                    context.fill(Path(ellipseIn: rect), with: .color(Theme.cardBorder.opacity(0.5)))
                    x += spacing
                }
                y += spacing
            }
        }
        .frame(width: mapSize, height: mapSize)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeIn(duration: 0.5), value: hasAppeared)
    }

    private var centerNode: some View {
        ZStack {
            ArcReactorView(size: 152, isActive: momentum >= 1)
            VStack(spacing: 2) {
                Text("\(Int(momentum * 100))%")
                    .font(.system(.title2, design: .rounded).weight(.heavy))
                    .monospacedDigit()
                    .foregroundStyle(Theme.primaryText)
                Text("TODAY")
                    .font(.caption2.weight(.bold))
                    .tracking(1.5)
                    .foregroundStyle(.white.opacity(0.85))
            }
        }
        .position(mapCenter)
        .scaleEffect(hasAppeared ? 1 : 0.2)
        .opacity(hasAppeared ? 1 : 0)
    }

    @ViewBuilder
    private func connector(index: Int, total: Int, section: MindMapSection) -> some View {
        let offset = nodeOffset(index: index, total: total)
        MindMapConnectorView(
            index: index,
            start: mapCenter,
            end: CGPoint(x: mapCenter.x + offset.x, y: mapCenter.y + offset.y),
            dotColor: section.accentColor,
            hasAppeared: hasAppeared
        )
    }

    private func nodeOffset(index: Int, total: Int) -> CGPoint {
        let angle = (2 * Double.pi * Double(index) / Double(total)) - .pi / 2
        return CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
    }

    private func badge(for section: MindMapSection) -> String? {
        switch section {
        case .today:
            return "\(doneToday)/\(scheduledToday.count)"
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
            return nil
        case .github:
            return nil
        case .school:
            return pendingAssignments == 0 ? nil : "\(pendingAssignments)"
        case .health:
            return healthHabits.isEmpty ? nil : "\(healthLoggedToday)/\(healthHabits.count)"
        case .calendar:
            return upcomingAgendaCount == 0 ? nil : "\(upcomingAgendaCount)"
        case .extracurriculars:
            return extracurriculars.isEmpty ? nil : "\(extracurriculars.count)"
        case .memory:
            return memories.isEmpty ? nil : "\(memories.count)"
        }
    }
}

#Preview {
    NavigationStack {
        MindMapHomeView()
            .navigationDestination(for: MindMapSection.self) { section in
                Text(section.title)
            }
    }
    .modelContainer(
        for: [Habit.self, Completion.self, Skill.self, SkillSession.self, Project.self, ProjectTask.self, NewsItem.self],
        inMemory: true
    )
}

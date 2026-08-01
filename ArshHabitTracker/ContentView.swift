//
//  ContentView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        NavigationStack {
            MindMapHomeView()
                .navigationDestination(for: MindMapSection.self) { section in
                    destination(for: section)
                }
        }
        .tint(Theme.accent)
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
        case .food: FoodView()
        case .workouts: WorkoutView()
        case .calendar: CalendarView()
        case .extracurriculars: ExtracurricularsView()
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(
            for: [
                Habit.self, Completion.self,
                Skill.self, SkillSession.self,
                Project.self, ProjectTask.self,
                NewsItem.self, ChatMessage.self,
                AIToolItem.self, Exam.self, StudySession.self,
                Assignment.self, QuizRecord.self,
            ],
            inMemory: true
        )
}

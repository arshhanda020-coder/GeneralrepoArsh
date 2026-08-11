//
//  StatsView.swift
//  Odysseus
//
//  A general progress overview — skills, projects, and test mastery. No
//  habit-streak concept.
//

import SwiftUI
import SwiftData

struct StatsView: View {
    @Query(sort: \Skill.createdAt) private var skills: [Skill]
    @Query(sort: \Project.createdAt) private var projects: [Project]
    @Query private var quizSessions: [QuizSession]

    private var submittedQuizzes: [QuizSession] { quizSessions.filter { $0.isSubmitted } }
    private var totalQuizScore: Int { submittedQuizzes.reduce(0) { $0 + $1.score } }
    private var totalQuizQuestions: Int { submittedQuizzes.reduce(0) { $0 + $1.totalQuestions } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if skills.isEmpty && projects.isEmpty && submittedQuizzes.isEmpty {
                    EmptyStateView(
                        icon: MindMapSection.stats.symbolName,
                        title: "Nothing to show yet",
                        message: "Progress on Skills, Projects, and Test Me quizzes will appear here.",
                        tint: MindMapSection.stats.accentColor
                    )
                    .glassPanel(cornerRadius: 14)
                    .padding(.top, 20)
                }

                if !skills.isEmpty {
                    section("SKILLS") {
                        ForEach(skills) { skill in
                            SkillStatsRow(skill: skill)
                        }
                    }
                }

                if !projects.isEmpty {
                    section("PROJECTS") {
                        ForEach(projects) { project in
                            projectRow(project)
                        }
                    }
                }

                if !submittedQuizzes.isEmpty {
                    section("TEST ME") {
                        HStack {
                            Text("Overall accuracy")
                                .font(.subheadline)
                                .foregroundStyle(Theme.primaryText)
                            Spacer()
                            Text(totalQuizQuestions == 0 ? "—" : "\(totalQuizScore)/\(totalQuizQuestions)")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(MindMapSection.school.accentColor)
                        }
                        .padding(10)
                        .glassPanel(cornerRadius: 8)

                        ForEach(Dictionary(grouping: submittedQuizzes, by: { $0.subject }).sorted(by: { $0.key < $1.key }), id: \.key) { subject, sessions in
                            let done = sessions.reduce(0) { $0 + $1.score }
                            let total = sessions.reduce(0) { $0 + $1.totalQuestions }
                            HStack {
                                Text(subject).font(.caption.weight(.medium)).foregroundStyle(Theme.primaryText)
                                Spacer()
                                Text("\(done)/\(total)").font(.caption.monospacedDigit()).foregroundStyle(Theme.dimText)
                            }
                            .padding(8)
                        }
                    }
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Stats")
        .sectionAssistantButton(.stats)
    }

    @ViewBuilder
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(spacing: 6) {
                content()
            }
        }
    }

    private func projectRow(_ project: Project) -> some View {
        HStack(spacing: 8) {
            Text(project.emoji).font(.subheadline)
            VStack(alignment: .leading, spacing: 3) {
                Text(project.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                ProgressView(value: project.progress)
                    .tint(Color(hex: project.colorHex))
            }
            Spacer()
            let done = project.tasks.filter { $0.isDone }.count
            Text("\(done)/\(project.tasks.count)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.dimText)
        }
        .padding(8)
        .glassPanel(cornerRadius: 8)
    }
}

#Preview {
    NavigationStack {
        StatsView()
    }
    .modelContainer(for: [Skill.self, SkillSession.self, Project.self, ProjectTask.self, QuizSession.self, QuizQuestion.self], inMemory: true)
}

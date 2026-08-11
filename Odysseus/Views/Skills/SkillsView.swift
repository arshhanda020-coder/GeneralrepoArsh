//
//  SkillsView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct SkillsView: View {
    @Query(sort: \Skill.createdAt) private var skills: [Skill]

    @State private var showingAddSkill = false
    @State private var loggingSkill: Skill?

    private var inProgress: [Skill] { skills.filter { !$0.isLearned } }
    private var completed: [Skill] { skills.filter { $0.isLearned } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                ForEach(inProgress) { skill in
                    SkillCardView(skill: skill) { loggingSkill = skill }
                }

                if !completed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("COMPLETED")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Theme.dimText)

                        ForEach(completed) { skill in
                            SkillCardView(skill: skill) { loggingSkill = skill }
                        }
                    }
                }

                if skills.isEmpty {
                    EmptyStateView(
                        icon: MindMapSection.skills.symbolName,
                        title: "No skills yet",
                        message: "Tap + to add one.",
                        tint: MindMapSection.skills.accentColor
                    )
                    .glassPanel(cornerRadius: 14)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Skills")
        .sectionAssistantButton(.skills)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddSkill = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddSkill) {
            AddEditSkillView(skill: nil)
        }
        .sheet(item: $loggingSkill) { skill in
            LogSkillSessionSheet(skill: skill)
        }
    }
}

#Preview {
    NavigationStack {
        SkillsView()
    }
    .modelContainer(for: [Skill.self, SkillSession.self], inMemory: true)
}

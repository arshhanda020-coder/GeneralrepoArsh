//
//  NoteMoveSheet.swift
//  Odysseus
//
//  Where a note can live: standalone (Notes hub only), pinned to Today, or
//  attached to a Project / School topic / Subagent. Shared by both `Note`
//  and `DocNote` — either one can be moved anywhere in the app.
//

import SwiftUI
import SwiftData

struct NoteMoveSheet: View {
    let current: NoteContext?
    let onSelect: (NoteContext?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Project.name) private var projects: [Project]
    @Query(sort: \Topic.name) private var topics: [Topic]
    @Query(sort: \AgentDefinition.name) private var agents: [AgentDefinition]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    optionRow(label: "Standalone", subtitle: "Notes hub only", symbol: "tray", isSelected: current == nil) {
                        choose(nil)
                    }
                    optionRow(label: "Pin to Today", subtitle: "Shows as a quick reminder", symbol: "checkmark.seal", isSelected: current == .today) {
                        choose(.today)
                    }
                }

                if !projects.isEmpty {
                    Section("PROJECTS") {
                        ForEach(projects) { project in
                            optionRow(label: project.name, subtitle: nil, symbol: "hammer", isSelected: current == .project(project.id)) {
                                choose(.project(project.id))
                            }
                        }
                    }
                }

                if !topics.isEmpty {
                    Section("SCHOOL TOPICS") {
                        ForEach(topics) { topic in
                            optionRow(
                                label: topic.name,
                                subtitle: topic.schoolClass?.name,
                                symbol: "graduationcap.fill",
                                isSelected: current == .topic(topic.id)
                            ) {
                                choose(.topic(topic.id))
                            }
                        }
                    }
                }

                if !agents.isEmpty {
                    Section("SUBAGENTS") {
                        ForEach(agents) { agent in
                            optionRow(label: agent.name, subtitle: nil, symbol: "cpu", isSelected: current == .agentDefinition(agent.id)) {
                                choose(.agentDefinition(agent.id))
                            }
                        }
                    }
                }
            }
            .navigationTitle("Move Note")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func optionRow(label: String, subtitle: String?, symbol: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Label(label, systemImage: symbol)
                        .foregroundStyle(Theme.primaryText)
                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                            .padding(.leading, 24)
                    }
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                        .foregroundStyle(MindMapSection.notes.accentColor)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func choose(_ context: NoteContext?) {
        onSelect(context)
        dismiss()
    }
}

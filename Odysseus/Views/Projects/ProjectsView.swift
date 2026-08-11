//
//  ProjectsView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct ProjectsView: View {
    @Query(sort: \Project.createdAt) private var projects: [Project]

    @State private var showingAddProject = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                groupedList

                if projects.isEmpty {
                    EmptyStateView(
                        icon: MindMapSection.projects.symbolName,
                        title: "No projects yet",
                        message: "Tap + to add one.",
                        tint: MindMapSection.projects.accentColor
                    )
                    .glassPanel(cornerRadius: 14)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Projects")
        .sectionAssistantButton(.projects)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddProject = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddProject) {
            AddEditProjectView(project: nil)
        }
    }

    private var groupedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(projects.enumerated()), id: \.element.id) { index, project in
                if index > 0 {
                    Divider().overlay(Theme.cardBorder)
                }
                NavigationLink(destination: ProjectDetailView(project: project)) {
                    ProjectRowView(project: project)
                }
                .buttonStyle(.plain)
            }
        }
        .glassPanel(cornerRadius: 10)
    }
}

#Preview {
    NavigationStack {
        ProjectsView()
    }
    .modelContainer(for: [Project.self, ProjectTask.self], inMemory: true)
}

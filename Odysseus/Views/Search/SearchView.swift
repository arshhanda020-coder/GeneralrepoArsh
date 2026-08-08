//
//  SearchView.swift
//  Odysseus
//
//  Global search across the app's own data. Presented as a sheet with its
//  own NavigationStack, so a result can push straight into its real screen.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(\.dismiss) private var dismiss

    @Query private var assignments: [Assignment]
    @Query private var projects: [Project]
    @Query private var skills: [Skill]
    @Query private var newsItems: [NewsItem]
    @Query private var extracurriculars: [Extracurricular]
    @Query private var classes: [SchoolClass]

    @State private var queryText = ""

    private var trimmed: String { queryText.trimmingCharacters(in: .whitespacesAndNewlines) }
    private func matches(_ text: String) -> Bool { !trimmed.isEmpty && text.localizedCaseInsensitiveContains(trimmed) }

    private var matchedAssignments: [Assignment] { assignments.filter { matches($0.title) } }
    private var matchedProjects: [Project] { projects.filter { matches($0.name) } }
    private var matchedSkills: [Skill] { skills.filter { matches($0.name) } }
    private var matchedNews: [NewsItem] { newsItems.filter { matches($0.title) } }
    private var matchedExtracurriculars: [Extracurricular] { extracurriculars.filter { matches($0.title) } }
    private var matchedClasses: [SchoolClass] { classes.filter { matches($0.name) } }

    private var hasAnyResults: Bool {
        !(matchedAssignments.isEmpty && matchedProjects.isEmpty
            && matchedSkills.isEmpty && matchedNews.isEmpty && matchedExtracurriculars.isEmpty && matchedClasses.isEmpty)
    }

    var body: some View {
        NavigationStack {
            List {
                if trimmed.isEmpty {
                    Text("Search assignments, classes, projects, skills, news, and extracurriculars.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                } else if !hasAnyResults {
                    Text("No matches for \"\(trimmed)\".")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                } else {
                    resultSection("Classes", matchedClasses) { schoolClass in
                        NavigationLink(schoolClass.name) { SchoolClassDetailView(schoolClass: schoolClass) }
                    }
                    resultSection("Assignments", matchedAssignments) { assignment in
                        if let topic = assignment.topic {
                            NavigationLink(assignment.title) { TopicDetailView(topic: topic) }
                        } else {
                            NavigationLink(assignment.title) { SchoolView() }
                        }
                    }
                    resultSection("Projects", matchedProjects) { project in
                        NavigationLink(project.name) { ProjectDetailView(project: project) }
                    }
                    resultSection("Skills", matchedSkills) { skill in
                        NavigationLink(skill.name) { SkillsView() }
                    }
                    resultSection("Extracurriculars", matchedExtracurriculars) { item in
                        NavigationLink(item.title) { ExtracurricularsView() }
                    }
                    resultSection("News", matchedNews) { item in
                        NavigationLink(item.title) { NewsItemDetailView(item: item) }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Theme.background.ignoresSafeArea())
            .searchable(text: $queryText, prompt: "Search everything")
            .navigationTitle("Search")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func resultSection<T: Identifiable, Content: View>(
        _ title: String,
        _ items: [T],
        @ViewBuilder content: @escaping (T) -> Content
    ) -> some View {
        if !items.isEmpty {
            Section(title) {
                ForEach(items) { item in
                    content(item)
                }
            }
        }
    }
}

#Preview {
    SearchView()
}

//
//  ResearchView.swift
//  Odysseus
//
//  A dedicated place to research topics for school or new projects — quality,
//  AI-written write-ups (with web search when the active provider supports
//  it), not throwaway one-liners. School-category research automatically
//  also creates a matching Extracurricular entry, since research for school
//  is itself an activity worth having on record.
//

import SwiftUI
import SwiftData

struct ResearchView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ResearchEntry.createdAt, order: .reverse) private var entries: [ResearchEntry]
    @Query(sort: \Project.createdAt) private var projects: [Project]

    @State private var showingNew = false
    @State private var selectedEntry: ResearchEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if entries.isEmpty {
                    Text("Nothing researched yet. Tap + to research a topic for school, a new project, or anything else.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            row(entry)
                        }
                    }
                    .glassPanel(cornerRadius: 10)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Research")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNew = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            NewResearchSheet(projects: projects)
        }
        .navigationDestination(item: $selectedEntry) { entry in
            ResearchDetailView(entry: entry)
        }
    }

    private func row(_ entry: ResearchEntry) -> some View {
        HStack(spacing: 10) {
            Image(systemName: categoryIcon(entry.category))
                .foregroundStyle(MindMapSection.research.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.topic)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                HStack(spacing: 4) {
                    Text(entry.category.displayName.uppercased())
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(Theme.dimText)
                    if let project = entry.project {
                        Text("· \(project.name)")
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                    Text("· \(relativeTime(entry.createdAt))")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
            }
            Spacer()
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { selectedEntry = entry }
    }

    private func categoryIcon(_ category: ResearchCategory) -> String {
        switch category {
        case .school: return "graduationcap.fill"
        case .project: return "hammer.fill"
        case .other: return "magnifyingglass"
        }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

private struct NewResearchSheet: View {
    let projects: [Project]

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var topic = ""
    @State private var category: ResearchCategory = .school
    @State private var selectedProject: Project?
    @State private var isResearching = false
    @State private var error: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Topic") {
                    TextField("What do you want researched?", text: $topic, axis: .vertical)
                        .lineLimit(2...4)
                }
                Section("Category") {
                    Picker("Category", selection: $category) {
                        ForEach(ResearchCategory.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    if category == .school {
                        Text("This will also add a matching entry to Extracurriculars.")
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                    if category == .project {
                        Picker("Project", selection: $selectedProject) {
                            Text("None").tag(Project?.none)
                            ForEach(projects) { project in
                                Text(project.name).tag(Project?.some(project))
                            }
                        }
                    }
                }
                if let error {
                    Text(error).font(.caption).foregroundStyle(Color(hex: "FF6B6B"))
                }
            }
            .navigationTitle("New Research")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        research()
                    } label: {
                        if isResearching {
                            ProgressView()
                        } else {
                            Text("Research")
                        }
                    }
                    .disabled(isResearching || topic.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func research() {
        let trimmedTopic = topic.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTopic.isEmpty else { return }
        isResearching = true
        error = nil
        Task {
            do {
                let content = try await ResearchService.research(topic: trimmedTopic, category: category)
                let entry = ResearchEntry(topic: trimmedTopic, category: category, content: content, project: category == .project ? selectedProject : nil)

                if category == .school {
                    let activity = Extracurricular(
                        title: "Research: \(trimmedTopic)",
                        activityDescription: content.count > 400 ? String(content.prefix(400)) + "…" : content,
                        category: "Research",
                        isAISuggested: true
                    )
                    modelContext.insert(activity)
                    entry.linkedExtracurricularID = activity.id
                }

                modelContext.insert(entry)
                isResearching = false
                dismiss()
            } catch {
                self.error = error.localizedDescription
                isResearching = false
            }
        }
    }
}

private struct ResearchDetailView: View {
    let entry: ResearchEntry
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.topic)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text(entry.category.displayName.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(MindMapSection.research.accentColor)
                Divider().overlay(Theme.cardBorder)
                Text(entry.content)
                    .font(.subheadline)
                    .foregroundStyle(Theme.primaryText)
                    .textSelection(.enabled)
            }
            .padding(14)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Research")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Delete this research?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(entry)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }
}

#Preview {
    NavigationStack {
        ResearchView()
    }
    .modelContainer(for: [ResearchEntry.self, Project.self, Extracurricular.self], inMemory: true)
}

//
//  ProjectDetailView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct ProjectDetailView: View {
    let project: Project

    @Environment(\.modelContext) private var modelContext
    @State private var newTaskTitle = ""
    @State private var showingEdit = false

    private var accentColor: Color { Color(hex: project.colorHex) }

    private var sortedTasks: [ProjectTask] {
        project.tasks.sorted { $0.sortIndex < $1.sortIndex }
    }

    var body: some View {
        List {
            Section {
                header
                if !project.projectDescription.isEmpty {
                    Text(project.projectDescription)
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                }
                ProgressView(value: project.progress)
                    .tint(accentColor)
            }
            .listRowBackground(Theme.card)

            Section("TASKS") {
                ForEach(sortedTasks) { task in
                    taskRow(task)
                }
                .onDelete(perform: deleteTasks)
                .onMove(perform: moveTasks)

                addTaskRow
            }
            .listRowBackground(Theme.card)
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEdit = true
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            ToolbarItem(placement: .primaryAction) {
                EditButton()
            }
        }
        .sheet(isPresented: $showingEdit) {
            AddEditProjectView(project: project)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Text(project.emoji).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(project.name)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(project.tasks.filter { $0.isDone }.count)/\(project.tasks.count) tasks")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            statusPill
        }
    }

    private var statusPill: some View {
        Text(project.status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(project.status.color.opacity(0.18))
            .foregroundStyle(project.status.color)
            .clipShape(Capsule())
    }

    private func taskRow(_ task: ProjectTask) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    task.isDone.toggle()
                }
            } label: {
                Image(systemName: task.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(task.isDone ? accentColor : Theme.dimText)
            }
            .buttonStyle(.plain)

            Text(task.title)
                .foregroundStyle(task.isDone ? Theme.dimText : .white)
                .strikethrough(task.isDone)
        }
    }

    private var addTaskRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus.circle")
                .foregroundStyle(Theme.dimText)
            TextField("Add task", text: $newTaskTitle)
                .foregroundStyle(.white)
                .onSubmit(addTask)
        }
    }

    private func addTask() {
        let trimmed = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let task = ProjectTask(title: trimmed, sortIndex: project.tasks.count, project: project)
        modelContext.insert(task)
        newTaskTitle = ""
    }

    private func deleteTasks(at offsets: IndexSet) {
        let items = sortedTasks
        for index in offsets {
            modelContext.delete(items[index])
        }
    }

    private func moveTasks(from source: IndexSet, to destination: Int) {
        var items = sortedTasks
        items.move(fromOffsets: source, toOffset: destination)
        for (index, task) in items.enumerated() {
            task.sortIndex = index
        }
    }
}

//
//  TodayView.swift
//  Odysseus
//
//  A simple checklist — not habit templates, no streaks. Pulls in whatever's
//  actually due today or overdue from Assignments and Project tasks, and
//  lets you check things off right here (which marks the real underlying
//  item done wherever it actually lives).
//

import SwiftUI
import SwiftData

private struct ChecklistItem: Identifiable {
    enum Kind {
        case assignment(Assignment)
        case projectTask(ProjectTask)
    }

    let id: String
    let title: String
    let subtitle: String?
    let dueDate: Date?
    let isDone: Bool
    let kind: Kind

    @MainActor
    func toggle() {
        switch kind {
        case .assignment(let assignment):
            assignment.isDone.toggle()
            NotificationManager.shared.sync(assignment: assignment)
            if assignment.isDone { NotificationManager.shared.notifyTaskCompleted(title: assignment.title) }
        case .projectTask(let task):
            task.isDone.toggle()
            NotificationManager.shared.sync(projectTask: task)
            if task.isDone { NotificationManager.shared.notifyTaskCompleted(title: task.title) }
        }
    }
}

struct TodayView: View {
    @Query private var assignments: [Assignment]
    @Query private var projectTasks: [ProjectTask]

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var items: [ChecklistItem] {
        let assignmentItems: [ChecklistItem] = assignments.compactMap { assignment in
            guard let due = assignment.dueDate else { return nil }
            let dueDay = Calendar.current.startOfDay(for: due)
            guard dueDay <= today, dueDay == today || !assignment.isDone else { return nil }
            return ChecklistItem(
                id: "assignment-\(assignment.id)",
                title: assignment.title,
                subtitle: assignment.lesson?.topic?.schoolClass?.name ?? assignment.lesson?.topic?.name ?? assignment.lesson?.title,
                dueDate: due,
                isDone: assignment.isDone,
                kind: .assignment(assignment)
            )
        }
        let taskItems: [ChecklistItem] = projectTasks.compactMap { task in
            guard let due = task.dueDate else { return nil }
            let dueDay = Calendar.current.startOfDay(for: due)
            guard dueDay <= today, dueDay == today || !task.isDone else { return nil }
            return ChecklistItem(
                id: "task-\(task.id)",
                title: task.title,
                subtitle: task.project?.name,
                dueDate: due,
                isDone: task.isDone,
                kind: .projectTask(task)
            )
        }
        return (assignmentItems + taskItems).sorted {
            if $0.isDone != $1.isDone { return !$0.isDone && $1.isDone }
            return ($0.dueDate ?? .distantFuture) < ($1.dueDate ?? .distantFuture)
        }
    }

    private var doneCount: Int { items.filter { $0.isDone }.count }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                if items.isEmpty {
                    Text("Nothing due today. Assignments and project tasks with a due date of today (or overdue) show up here automatically.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                        .padding(.top, 20)
                } else {
                    HStack {
                        Text("\(doneCount)/\(items.count) done")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                        Spacer()
                    }

                    VStack(spacing: 0) {
                        ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            row(item)
                        }
                    }
                    .glassPanel(cornerRadius: 10)
                }

                NotesSectionView(context: .today, accentColor: MindMapSection.today.accentColor)
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Today")
        .inlineNavigationTitle()
        .sectionAssistantButton(.today)
    }

    private func row(_ item: ChecklistItem) -> some View {
        HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    item.toggle()
                }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.body)
                    .foregroundStyle(item.isDone ? MindMapSection.today.accentColor : Theme.dimText)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(item.isDone ? Theme.dimText : Theme.primaryText)
                    .strikethrough(item.isDone)
                if let subtitle = item.subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
            }
            Spacer()
            if let due = item.dueDate, Calendar.current.startOfDay(for: due) < today {
                Text("OVERDUE")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.negative)
            }
        }
        .padding(10)
    }
}

#Preview {
    NavigationStack {
        TodayView()
    }
    .modelContainer(for: [Assignment.self, ProjectTask.self], inMemory: true)
}

//
//  CalendarView.swift
//  Odysseus
//
//  A unified agenda across everything with a date: exams, assignments, and
//  project tasks. Not a separate data model — just a merged, date-grouped
//  view over what already exists. Presented as a navigable week strip (past
//  and future both reachable) with the selected day's items below.
//

import SwiftUI
import SwiftData

private struct AgendaItem: Identifiable {
    enum Kind { case exam, assignment, projectTask, projectDue }

    let id: String
    let title: String
    let subtitle: String?
    let date: Date
    let kind: Kind
    let isDone: Bool

    var accentColor: Color {
        switch kind {
        case .exam: return MindMapSection.school.accentColor
        case .assignment: return Theme.terminalAmber
        case .projectTask, .projectDue: return MindMapSection.projects.accentColor
        }
    }

    var symbolName: String {
        switch kind {
        case .exam: return "graduationcap.fill"
        case .assignment: return "checklist"
        case .projectTask: return "hammer.fill"
        case .projectDue: return "flag.checkered"
        }
    }
}

struct CalendarView: View {
    @Query private var exams: [Exam]
    @Query private var assignments: [Assignment]
    @Query private var projectTasks: [ProjectTask]
    @Query private var projects: [Project]

    @State private var weekStart: Date = CalendarView.startOfWeek(containing: .now)
    @State private var selectedDate: Date = Calendar.current.startOfDay(for: .now)

    private var today: Date { Calendar.current.startOfDay(for: .now) }

    private var allItems: [AgendaItem] {
        let examItems = exams.map {
            AgendaItem(id: "exam-\($0.id)", title: $0.name, subtitle: "Test", date: $0.examDate, kind: .exam, isDone: $0.isPast)
        }
        let assignmentItems = assignments.compactMap { assignment -> AgendaItem? in
            guard let due = assignment.dueDate else { return nil }
            return AgendaItem(id: "assignment-\(assignment.id)", title: assignment.title, subtitle: "Assignment", date: due, kind: .assignment, isDone: assignment.isDone)
        }
        let taskItems = projectTasks.compactMap { task -> AgendaItem? in
            guard let due = task.dueDate else { return nil }
            return AgendaItem(id: "task-\(task.id)", title: task.title, subtitle: task.project?.name ?? "Project", date: due, kind: .projectTask, isDone: task.isDone)
        }
        let projectDueItems = projects.compactMap { project -> AgendaItem? in
            guard let target = project.targetDate else { return nil }
            return AgendaItem(id: "project-\(project.id)", title: project.name, subtitle: "Project due", date: target, kind: .projectDue, isDone: project.status == .shipped)
        }
        return examItems + assignmentItems + taskItems + projectDueItems
    }

    private var weekDates: [Date] {
        (0..<7).compactMap { Calendar.current.date(byAdding: .day, value: $0, to: weekStart) }
    }

    private func items(on date: Date) -> [AgendaItem] {
        allItems
            .filter { Calendar.current.isDate($0.date, inSameDayAs: date) }
            .sorted { $0.date < $1.date }
    }

    private func dayHasItems(_ date: Date) -> Bool {
        allItems.contains { Calendar.current.isDate($0.date, inSameDayAs: date) }
    }

    var body: some View {
        VStack(spacing: 0) {
            weekHeader
            weekStrip

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    let dayItems = items(on: selectedDate)
                    if dayItems.isEmpty {
                        Text("Nothing due \(selectedDayLabel).")
                            .font(.subheadline)
                            .foregroundStyle(Theme.dimText)
                            .padding(.top, 20)
                    } else {
                        VStack(spacing: 0) {
                            ForEach(Array(dayItems.enumerated()), id: \.element.id) { index, item in
                                if index > 0 {
                                    Divider().overlay(Theme.cardBorder)
                                }
                                row(item)
                            }
                        }
                        .glassPanel(cornerRadius: 10)
                    }
                }
                .padding(12)
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Calendar")
        .inlineNavigationTitle()
        .sectionAssistantButton(.calendar)
    }

    private var weekHeader: some View {
        HStack {
            Button {
                shiftWeek(by: -1)
            } label: {
                Image(systemName: "chevron.left.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)

            Spacer()

            VStack(spacing: 1) {
                Text(monthLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                if !Calendar.current.isDate(weekStart, inSameDayAs: Self.startOfWeek(containing: .now)) {
                    Button("Jump to today") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            weekStart = Self.startOfWeek(containing: .now)
                            selectedDate = today
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(Theme.accent)
                }
            }

            Spacer()

            Button {
                shiftWeek(by: 1)
            } label: {
                Image(systemName: "chevron.right.circle.fill")
                    .font(.title3)
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private var weekStrip: some View {
        HStack(spacing: 6) {
            ForEach(weekDates, id: \.self) { date in
                dayCell(date)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
    }

    private func dayCell(_ date: Date) -> some View {
        let isSelected = Calendar.current.isDate(date, inSameDayAs: selectedDate)
        let isToday = Calendar.current.isDate(date, inSameDayAs: today)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { selectedDate = date }
        } label: {
            VStack(spacing: 4) {
                Text(date.formatted(.dateTime.weekday(.narrow)))
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.dimText)
                Text(date.formatted(.dateTime.day()))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(isSelected ? Color.white : Theme.primaryText)
                Circle()
                    .fill(dayHasItems(date) ? MindMapSection.calendar.accentColor : .clear)
                    .frame(width: 4, height: 4)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(isSelected ? MindMapSection.calendar.accentColor : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isToday && !isSelected ? MindMapSection.calendar.accentColor : Theme.cardBorder, lineWidth: isToday && !isSelected ? 1.5 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func row(_ item: AgendaItem) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.symbolName)
                .foregroundStyle(item.accentColor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                    .strikethrough(item.isDone)
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
            }
            Spacer()
            if item.isDone {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.terminalGreen)
            }
        }
        .padding(10)
    }

    private var selectedDayLabel: String {
        if Calendar.current.isDateInToday(selectedDate) { return "today" }
        if Calendar.current.isDateInTomorrow(selectedDate) { return "tomorrow" }
        if Calendar.current.isDateInYesterday(selectedDate) { return "yesterday" }
        return "on \(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))"
    }

    private var monthLabel: String {
        guard let last = weekDates.last, let first = weekDates.first else { return "" }
        if Calendar.current.isDate(first, equalTo: last, toGranularity: .month) {
            return first.formatted(.dateTime.month(.wide).year())
        }
        return "\(first.formatted(.dateTime.month(.abbreviated))) – \(last.formatted(.dateTime.month(.abbreviated).year()))"
    }

    private func shiftWeek(by weeks: Int) {
        guard let newStart = Calendar.current.date(byAdding: .weekOfYear, value: weeks, to: weekStart) else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            weekStart = newStart
        }
    }

    private static func startOfWeek(containing date: Date) -> Date {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: startOfDay)
        let daysToSubtract = weekday - calendar.firstWeekday
        let normalized = daysToSubtract < 0 ? daysToSubtract + 7 : daysToSubtract
        return calendar.date(byAdding: .day, value: -normalized, to: startOfDay) ?? startOfDay
    }
}

#Preview {
    NavigationStack {
        CalendarView()
    }
    .modelContainer(for: [Exam.self, Assignment.self, ProjectTask.self, Project.self], inMemory: true)
}

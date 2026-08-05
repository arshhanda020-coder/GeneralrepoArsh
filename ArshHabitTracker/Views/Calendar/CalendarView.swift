//
//  CalendarView.swift
//  ArshHabitTracker
//
//  A unified agenda across everything with a date: exams and assignments.
//  Not a separate data model — just a merged, date-grouped view over what
//  already exists.
//

import SwiftUI
import SwiftData

private struct AgendaItem: Identifiable {
    enum Kind { case exam, assignment }

    let id: String
    let title: String
    let subtitle: String?
    let date: Date
    let kind: Kind

    var accentColor: Color {
        kind == .exam ? MindMapSection.school.accentColor : Theme.terminalAmber
    }

    var symbolName: String {
        kind == .exam ? "graduationcap.fill" : "checklist"
    }
}

struct CalendarView: View {
    @Query private var exams: [Exam]
    @Query private var assignments: [Assignment]

    private var items: [AgendaItem] {
        let examItems = exams.map {
            AgendaItem(id: "exam-\($0.id)", title: $0.name, subtitle: "Test", date: $0.examDate, kind: .exam)
        }
        let assignmentItems = assignments.compactMap { assignment -> AgendaItem? in
            guard let due = assignment.dueDate, !assignment.isDone else { return nil }
            return AgendaItem(id: "assignment-\(assignment.id)", title: assignment.title, subtitle: "Assignment", date: due, kind: .assignment)
        }
        return (examItems + assignmentItems).sorted { $0.date < $1.date }
    }

    private var upcoming: [AgendaItem] {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        return items.filter { $0.date >= startOfToday }
    }

    private var groupedByDay: [(date: Date, items: [AgendaItem])] {
        let groups = Dictionary(grouping: upcoming) { Calendar.current.startOfDay(for: $0.date) }
        return groups.keys.sorted().map { day in (day, groups[day] ?? []) }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if groupedByDay.isEmpty {
                    Text("Nothing on the calendar. Add exams or assignment due dates in School.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                } else {
                    ForEach(groupedByDay, id: \.date) { entry in
                        daySection(date: entry.date, items: entry.items)
                    }
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Calendar")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func daySection(date: Date, items: [AgendaItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayLabel(date).uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    if index > 0 {
                        Divider().overlay(Theme.cardBorder)
                    }
                    row(item)
                }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
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
                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
            }
            Spacer()
        }
        .padding(10)
    }

    private func dayLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInTomorrow(date) { return "Tomorrow" }
        return date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day())
    }
}

#Preview {
    NavigationStack {
        CalendarView()
    }
    .modelContainer(for: [Exam.self, Assignment.self], inMemory: true)
}

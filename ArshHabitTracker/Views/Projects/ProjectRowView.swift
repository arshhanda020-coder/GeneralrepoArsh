//
//  ProjectRowView.swift
//  ArshHabitTracker
//

import SwiftUI

struct ProjectRowView: View {
    let project: Project

    private var accentColor: Color { Color(hex: project.colorHex) }

    var body: some View {
        HStack(spacing: 10) {
            Text(project.emoji)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(project.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Spacer()
                    statusPill
                }
                ProgressView(value: project.progress)
                    .tint(accentColor)
                Text("\(project.tasks.filter { $0.isDone }.count)/\(project.tasks.count) tasks")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
            }

            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var statusPill: some View {
        Text(project.status.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(project.status.color.opacity(0.18))
            .foregroundStyle(project.status.color)
            .clipShape(Capsule())
    }
}

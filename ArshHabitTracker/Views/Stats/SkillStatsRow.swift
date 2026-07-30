//
//  SkillStatsRow.swift
//  ArshHabitTracker
//

import SwiftUI

struct SkillStatsRow: View {
    let skill: Skill

    var body: some View {
        HStack(spacing: 8) {
            Text(skill.emoji)
                .font(.subheadline)

            VStack(alignment: .leading, spacing: 3) {
                Text(skill.name)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white)
                ProgressView(value: skill.progress)
                    .tint(Color(hex: skill.colorHex))
            }

            Spacer()

            Text("\(skill.sessions.count)/\(skill.targetSessions)")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.dimText)
        }
        .padding(8)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
    }
}

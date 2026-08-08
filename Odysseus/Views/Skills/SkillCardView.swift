//
//  SkillCardView.swift
//  Odysseus
//

import SwiftUI

struct SkillCardView: View {
    let skill: Skill
    var onLog: () -> Void

    private var accentColor: Color { Color(hex: skill.colorHex) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(skill.emoji)
                    .font(.subheadline)

                VStack(alignment: .leading, spacing: 1) {
                    Text(skill.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    Text(skill.skillDescription)
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                        .lineLimit(2)
                }

                Spacer()

                if skill.isLearned {
                    Image(systemName: "checkmark.seal.fill")
                        .foregroundStyle(accentColor)
                        .font(.subheadline)
                }
            }

            ProgressView(value: skill.progress)
                .tint(accentColor)

            HStack {
                Text("\(skill.sessions.count)/\(skill.targetSessions) sessions")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)

                Spacer()

                if !skill.isLearned {
                    Button("Log session", action: onLog)
                        .font(.caption2.weight(.semibold))
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                        .controlSize(.small)
                }
            }
        }
        .padding(10)
        .glassPanel(cornerRadius: 10)
    }
}

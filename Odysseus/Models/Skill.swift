//
//  Skill.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class Skill {
    var id: String = UUID().uuidString
    var name: String = ""
    var emoji: String = ""
    var colorHex: String = ""
    var skillDescription: String = ""
    var createdAt: Date = .now
    var targetSessions: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \SkillSession.skill)
    var sessions: [SkillSession] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        emoji: String,
        colorHex: String,
        skillDescription: String,
        createdAt: Date = .now,
        targetSessions: Int
    ) {
        self.id = id
        self.name = name
        self.emoji = emoji
        self.colorHex = colorHex
        self.skillDescription = skillDescription
        self.createdAt = createdAt
        self.targetSessions = targetSessions
    }

    var isLearned: Bool { sessions.count >= targetSessions }

    var progress: Double {
        guard targetSessions > 0 else { return 0 }
        return min(1, Double(sessions.count) / Double(targetSessions))
    }
}

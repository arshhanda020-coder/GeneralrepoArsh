//
//  SkillSession.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class SkillSession {
    var date: Date
    var note: String?
    var skill: Skill?

    init(date: Date = .now, note: String? = nil, skill: Skill? = nil) {
        self.date = date
        self.note = note
        self.skill = skill
    }
}

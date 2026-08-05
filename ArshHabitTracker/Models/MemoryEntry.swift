//
//  MemoryEntry.swift
//  ArshHabitTracker
//
//  A single fact the AI (Jarvis/Copilot) remembers about the user across
//  every future conversation — either saved automatically mid-chat or added
//  by hand here.
//

import Foundation
import SwiftData

@Model
final class MemoryEntry {
    var id: String
    var content: String
    var isAISaved: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        content: String,
        isAISaved: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.content = content
        self.isAISaved = isAISaved
        self.createdAt = createdAt
    }
}

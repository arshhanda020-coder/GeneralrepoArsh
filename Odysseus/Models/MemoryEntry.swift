//
//  MemoryEntry.swift
//  Odysseus
//
//  A single fact the AI (Odysseus/Copilot) remembers about the user across
//  every future conversation — either saved automatically mid-chat or added
//  by hand here.
//

import Foundation
import SwiftData

@Model
final class MemoryEntry {
    var id: String = UUID().uuidString
    var content: String = ""
    var isAISaved: Bool = false
    var createdAt: Date = .now

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

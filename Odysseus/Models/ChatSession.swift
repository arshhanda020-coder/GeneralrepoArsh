//
//  ChatSession.swift
//  Odysseus
//
//  A single Copilot/Odysseus conversation thread. Old sessions are never
//  auto-deleted — starting a new chat just creates another one and switches
//  the active pointer, so history stays organized instead of one endless log.
//

import Foundation
import SwiftData

@Model
final class ChatSession {
    var id: String
    var title: String
    var createdAt: Date
    var lastActivityAt: Date
    /// Nil for a main Copilot thread. Set to a `MindMapSection`'s rawValue
    /// for a section assistant's thread, so each section's chat is its own
    /// history instead of all sharing (or colliding with) the Copilot log.
    var sectionKey: String?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    init(
        id: String = UUID().uuidString,
        title: String = "New Chat",
        createdAt: Date = .now,
        lastActivityAt: Date = .now,
        sectionKey: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.sectionKey = sectionKey
    }
}

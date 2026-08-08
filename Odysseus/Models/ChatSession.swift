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
    var id: String = UUID().uuidString
    var title: String = "New Chat"
    var createdAt: Date = .now
    var lastActivityAt: Date = .now

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    init(
        id: String = UUID().uuidString,
        title: String = "New Chat",
        createdAt: Date = .now,
        lastActivityAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
    }
}

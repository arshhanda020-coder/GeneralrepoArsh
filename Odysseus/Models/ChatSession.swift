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
    /// Set when this thread is a per-topic Study Assistant session (School)
    /// rather than a general Copilot conversation — holds the `Topic.id`.
    /// Nil for every ordinary Copilot session. Used to keep the two kinds of
    /// thread out of each other's history list.
    var topicID: String?

    @Relationship(deleteRule: .cascade, inverse: \ChatMessage.session)
    var messages: [ChatMessage] = []

    init(
        id: String = UUID().uuidString,
        title: String = "New Chat",
        createdAt: Date = .now,
        lastActivityAt: Date = .now,
        topicID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.createdAt = createdAt
        self.lastActivityAt = lastActivityAt
        self.topicID = topicID
    }
}

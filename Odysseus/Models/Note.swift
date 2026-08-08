//
//  Note.swift
//  Odysseus
//
//  A freeform note you write yourself (as opposed to `DocNote`, which is
//  pulled in from Google Docs or a Notability export). Lives standalone in
//  the Notes hub by default, but can be attached to a `NoteContext` — a
//  Project, a School topic, a Subagent, or pinned to Today as a quick
//  reminder — and moved between those at any time.
//

import Foundation
import SwiftData

@Model
final class Note {
    var id: String
    var title: String
    var content: String
    var createdAt: Date
    var updatedAt: Date
    var contextTypeRaw: String?
    var contextID: String?
    /// Only meaningful when pinned to Today: lets a quick reminder note be
    /// checked off (like a task) without deleting it.
    var isDone: Bool

    init(
        id: String = UUID().uuidString,
        title: String,
        content: String = "",
        createdAt: Date = .now,
        updatedAt: Date = .now,
        context: NoteContext? = nil,
        isDone: Bool = false
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.contextTypeRaw = context?.typeRaw
        self.contextID = context?.recordID
        self.isDone = isDone
    }
}

extension Note: NoteContextLinkable {}

//
//  ObsidianNote.swift
//  Odysseus
//
//  A cached copy of one markdown file from the user's connected Obsidian
//  vault folder — re-synced on demand from ObsidianVaultManager, not a live
//  file handle (SwiftData needs its own persisted copy to query/display).
//

import Foundation
import SwiftData

@Model
final class ObsidianNote {
    var id: String = UUID().uuidString
    var title: String = ""
    var excerpt: String = ""
    var content: String = ""
    var relativePath: String = ""
    var modifiedAt: Date = .now

    init(
        id: String = UUID().uuidString,
        title: String,
        excerpt: String,
        content: String,
        relativePath: String,
        modifiedAt: Date
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.content = content
        self.relativePath = relativePath
        self.modifiedAt = modifiedAt
    }
}

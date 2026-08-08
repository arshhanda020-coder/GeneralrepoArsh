//
//  DocNote.swift
//  Odysseus
//
//  A note imported from an external source that isn't a live-synced folder
//  like Obsidian: a Google Doc pulled via the Docs API, or a Notability
//  export (Notability has no public API — the user exports a note as PDF/
//  RTF/plain text from the Notability app and imports the file here).
//

import Foundation
import SwiftData

enum DocNoteSource: String, Codable {
    case googleDocs
    case notability

    var label: String {
        switch self {
        case .googleDocs: return "Google Docs"
        case .notability: return "Notability"
        }
    }
}

@Model
final class DocNote {
    var id: String
    var title: String
    var excerpt: String
    var content: String
    var sourceRaw: String
    /// Google Doc file ID for `.googleDocs`, or the imported file's original
    /// name for `.notability` — used to upsert on re-import instead of
    /// duplicating.
    var sourceIdentifier: String
    var modifiedAt: Date
    var importedAt: Date

    var source: DocNoteSource {
        get { DocNoteSource(rawValue: sourceRaw) ?? .notability }
        set { sourceRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        excerpt: String,
        content: String,
        source: DocNoteSource,
        sourceIdentifier: String,
        modifiedAt: Date,
        importedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.excerpt = excerpt
        self.content = content
        self.sourceRaw = source.rawValue
        self.sourceIdentifier = sourceIdentifier
        self.modifiedAt = modifiedAt
        self.importedAt = importedAt
    }
}

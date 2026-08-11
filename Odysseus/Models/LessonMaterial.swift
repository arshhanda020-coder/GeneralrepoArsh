//
//  LessonMaterial.swift
//  Odysseus
//
//  A Google Classroom–style piece of course material attached to a lesson —
//  a link, an uploaded document, a slideshow, or a downloadable file.
//  Either a URL or an attached file's data is present, depending on how it
//  was added.
//

import Foundation
import SwiftData

enum MaterialKind: String, Codable, CaseIterable, Identifiable {
    case link, document, slideshow, download

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .link: return "Link"
        case .document: return "Document"
        case .slideshow: return "Slideshow"
        case .download: return "Download"
        }
    }

    var icon: String {
        switch self {
        case .link: return "link"
        case .document: return "doc.text.fill"
        case .slideshow: return "rectangle.on.rectangle.fill"
        case .download: return "arrow.down.circle.fill"
        }
    }
}

@Model
final class LessonMaterial {
    var id: String = UUID().uuidString
    var title: String = ""
    var kindRaw: String = MaterialKind.link.rawValue
    /// Populated for link-style material, or when a file-type material points
    /// out to an external URL (e.g. a Google Slides deck) instead of an
    /// attached file.
    var urlString: String?
    /// Populated when an actual file was attached (document/slideshow/download).
    var fileData: Data?
    var fileName: String?
    var notes: String?
    var createdAt: Date = Date.now
    var lesson: Lesson?

    var kind: MaterialKind {
        get { MaterialKind(rawValue: kindRaw) ?? .link }
        set { kindRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        title: String,
        kind: MaterialKind = .link,
        urlString: String? = nil,
        fileData: Data? = nil,
        fileName: String? = nil,
        notes: String? = nil,
        createdAt: Date = .now,
        lesson: Lesson? = nil
    ) {
        self.id = id
        self.title = title
        self.kindRaw = kind.rawValue
        self.urlString = urlString
        self.fileData = fileData
        self.fileName = fileName
        self.notes = notes
        self.createdAt = createdAt
        self.lesson = lesson
    }
}

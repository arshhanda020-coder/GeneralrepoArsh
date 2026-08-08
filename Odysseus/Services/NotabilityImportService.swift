//
//  NotabilityImportService.swift
//  Odysseus
//
//  Notability has no public API — there's no vault folder or web endpoint to
//  sync against the way ObsidianVaultManager does. The only real integration
//  point is Notability's own Export (Share sheet -> PDF, RTF, or plain text),
//  which lands a file in Files/iCloud Drive that the user then imports here
//  via the system file picker. This extracts readable text out of whichever
//  format they exported and upserts it into DocNote.
//

import Foundation
import SwiftData
import PDFKit

@MainActor
enum NotabilityImportService {
    enum ImportError: LocalizedError {
        case unreadable(String)
        case unsupportedFormat(String)

        var errorDescription: String? {
            switch self {
            case .unreadable(let name):
                return "Couldn't read \"\(name)\". It may be corrupted or protected."
            case .unsupportedFormat(let ext):
                return "\".\(ext)\" isn't supported. Export from Notability as PDF, RTF, or plain text."
            }
        }
    }

    /// Reads one exported Notability file and upserts it into SwiftData by
    /// file name, so re-importing an updated export replaces the old copy
    /// instead of duplicating it.
    static func importFile(at url: URL, modelContext: ModelContext) throws {
        guard url.startAccessingSecurityScopedResource() else {
            throw ImportError.unreadable(url.lastPathComponent)
        }
        defer { url.stopAccessingSecurityScopedResource() }

        let name = url.deletingPathExtension().lastPathComponent
        let text: String
        switch url.pathExtension.lowercased() {
        case "pdf":
            text = try Self.extractPDFText(url: url, name: name)
        case "rtf":
            text = try Self.extractRTFText(url: url, name: name)
        case "txt", "md":
            guard let raw = try? String(contentsOf: url, encoding: .utf8) else {
                throw ImportError.unreadable(name)
            }
            text = raw
        default:
            throw ImportError.unsupportedFormat(url.pathExtension)
        }

        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .now
        let excerpt = String(text.trimmingCharacters(in: .whitespacesAndNewlines).prefix(220))

        let identifier = url.lastPathComponent
        let existing = try? modelContext.fetch(FetchDescriptor<DocNote>(
            predicate: #Predicate { $0.sourceIdentifier == identifier && $0.sourceRaw == "notability" }
        ))

        if let note = existing?.first {
            note.title = name
            note.content = text
            note.excerpt = excerpt
            note.modifiedAt = modified
        } else {
            let note = DocNote(
                title: name,
                excerpt: excerpt,
                content: text,
                source: .notability,
                sourceIdentifier: identifier,
                modifiedAt: modified
            )
            modelContext.insert(note)
        }
        try? modelContext.save()
    }

    private static func extractPDFText(url: URL, name: String) throws -> String {
        guard let document = PDFDocument(url: url) else {
            throw ImportError.unreadable(name)
        }
        var pages: [String] = []
        for index in 0..<document.pageCount {
            if let page = document.page(at: index), let text = page.string {
                pages.append(text)
            }
        }
        return pages.joined(separator: "\n\n")
    }

    private static func extractRTFText(url: URL, name: String) throws -> String {
        guard let data = try? Data(contentsOf: url),
              let attributed = try? NSAttributedString(
                data: data,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
              ) else {
            throw ImportError.unreadable(name)
        }
        return attributed.string
    }
}

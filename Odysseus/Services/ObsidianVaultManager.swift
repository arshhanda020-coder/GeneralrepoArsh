//
//  ObsidianVaultManager.swift
//  Odysseus
//
//  Connects to an Obsidian vault the same way any iOS app reaches a folder
//  it doesn't own: the user picks it once via the system folder picker, we
//  keep a security-scoped bookmark, and re-resolve it on every sync. There
//  is no Obsidian API — a vault is just a folder of .md files.
//

import Foundation
import SwiftData
import Combine

@MainActor
final class ObsidianVaultManager: ObservableObject {
    static let shared = ObsidianVaultManager()

    @Published private(set) var vaultName: String?
    @Published private(set) var lastSyncedAt: Date?
    @Published private(set) var isSyncing = false
    @Published private(set) var lastError: String?

    private static let bookmarkKey = "obsidian_vault_bookmark"
    private static let vaultNameKey = "obsidian_vault_name"
    private static let lastSyncedKey = "obsidian_vault_last_synced"

    private init() {
        vaultName = UserDefaults.standard.string(forKey: Self.vaultNameKey)
        if let interval = UserDefaults.standard.object(forKey: Self.lastSyncedKey) as? TimeInterval {
            lastSyncedAt = Date(timeIntervalSince1970: interval)
        }
    }

    var isConnected: Bool { vaultName != nil }

    /// Called with the URL the user picked via `.fileImporter`. Stores a
    /// security-scoped bookmark so we can re-open the folder on later
    /// launches without asking again.
    func connect(url: URL, modelContext: ModelContext) {
        guard url.startAccessingSecurityScopedResource() else {
            lastError = "Couldn't access that folder."
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let bookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            UserDefaults.standard.set(bookmark, forKey: Self.bookmarkKey)
            UserDefaults.standard.set(url.lastPathComponent, forKey: Self.vaultNameKey)
            vaultName = url.lastPathComponent
            lastError = nil
            sync(modelContext: modelContext)
        } catch {
            lastError = "Couldn't save vault access: \(error.localizedDescription)"
        }
    }

    func disconnect(modelContext: ModelContext) {
        UserDefaults.standard.removeObject(forKey: Self.bookmarkKey)
        UserDefaults.standard.removeObject(forKey: Self.vaultNameKey)
        UserDefaults.standard.removeObject(forKey: Self.lastSyncedKey)
        vaultName = nil
        lastSyncedAt = nil
        if let existing = try? modelContext.fetch(FetchDescriptor<ObsidianNote>()) {
            for note in existing { modelContext.delete(note) }
            try? modelContext.save()
        }
    }

    /// Re-scans every `.md` file in the vault and upserts it into SwiftData
    /// by relative path, so re-syncing updates changed notes in place
    /// instead of duplicating them.
    func sync(modelContext: ModelContext) {
        guard let bookmarkData = UserDefaults.standard.data(forKey: Self.bookmarkKey) else {
            lastError = "No vault connected."
            return
        }

        isSyncing = true
        defer { isSyncing = false }

        var isStale = false
        guard let root = try? URL(
            resolvingBookmarkData: bookmarkData,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else {
            lastError = "Vault folder is no longer accessible. Reconnect it."
            return
        }

        guard root.startAccessingSecurityScopedResource() else {
            lastError = "Couldn't access the vault folder."
            return
        }
        defer { root.stopAccessingSecurityScopedResource() }

        let existing = (try? modelContext.fetch(FetchDescriptor<ObsidianNote>())) ?? []
        var byPath = Dictionary(uniqueKeysWithValues: existing.map { ($0.relativePath, $0) })
        var seenPaths = Set<String>()

        let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )

        while let fileURL = enumerator?.nextObject() as? URL {
            guard fileURL.pathExtension.lowercased() == "md" else { continue }
            guard let raw = try? String(contentsOf: fileURL, encoding: .utf8) else { continue }

            let relativePath = fileURL.path.replacingOccurrences(of: root.path, with: "")
            let modified = (try? fileURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .now
            let title = fileURL.deletingPathExtension().lastPathComponent
            let body = Self.stripFrontMatter(raw)
            let excerpt = String(body.trimmingCharacters(in: .whitespacesAndNewlines).prefix(220))

            seenPaths.insert(relativePath)
            if let note = byPath[relativePath] {
                note.title = title
                note.excerpt = excerpt
                note.content = body
                note.modifiedAt = modified
            } else {
                let note = ObsidianNote(title: title, excerpt: excerpt, content: body, relativePath: relativePath, modifiedAt: modified)
                modelContext.insert(note)
                byPath[relativePath] = note
            }
        }

        for (path, note) in byPath where !seenPaths.contains(path) {
            modelContext.delete(note)
        }

        try? modelContext.save()
        lastSyncedAt = .now
        UserDefaults.standard.set(Date.now.timeIntervalSince1970, forKey: Self.lastSyncedKey)
        lastError = nil
    }

    /// Drops a leading YAML front-matter block (`--- ... ---`) so previews
    /// show actual note content, not metadata.
    private static func stripFrontMatter(_ text: String) -> String {
        guard text.hasPrefix("---") else { return text }
        let lines = text.components(separatedBy: "\n")
        guard lines.count > 1 else { return text }
        for (index, line) in lines.enumerated().dropFirst() where line.trimmingCharacters(in: .whitespaces) == "---" {
            return lines[(index + 1)...].joined(separator: "\n")
        }
        return text
    }
}

//
//  MemoryVaultSync.swift
//  Odysseus
//
//  Mirrors MemoryEntry (SwiftData, source of truth — see MemoryStore) out to
//  the connected Obsidian vault as real markdown files: one fact per file
//  under <vault>/Memory/, plus a Memory.md index note. Same one-fact-per-file
//  + index scheme Claude's own persistent memory uses, so the AI's memory
//  becomes an actual vault you can browse, search, and version in Obsidian —
//  not just an in-app list.
//
//  This is push-only (app -> vault). Editing a file in Obsidian directly
//  won't change the in-app fact; re-adding/editing/deleting from the Memory
//  tab is what keeps the vault copy current.
//

import Foundation
import SwiftData

@MainActor
enum MemoryVaultSync {
    static let folderName = "Memory"
    private static let indexFileName = "Memory.md"

    /// True if `relativePath` (as reported by ObsidianVaultManager.sync,
    /// leading-slash style) falls under the Memory tab's own vault folder.
    static func isMemoryFile(_ relativePath: String) -> Bool {
        relativePath.hasPrefix("/\(folderName)/") || relativePath.hasPrefix("\(folderName)/")
    }

    /// Writes every MemoryEntry out to <vault>/Memory/<slug>.md, removes
    /// vault files for entries that no longer exist, and refreshes the
    /// Memory.md index. No-op if no vault is connected. Call this alongside
    /// MemoryStore.rebuild(context:) after any insert/edit/delete.
    static func pushToVault(entries: [MemoryEntry], modelContext: ModelContext) {
        guard ObsidianVaultManager.shared.isConnected else { return }
        guard let root = ObsidianVaultManager.shared.resolveVaultRoot() else { return }
        defer { root.stopAccessingSecurityScopedResource() }

        let folder = root.appendingPathComponent(folderName, isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)) != nil else { return }

        var writtenFileNames = Set<String>()
        for entry in entries {
            let fileName = fileName(for: entry)
            if entry.vaultFileName != fileName { entry.vaultFileName = fileName }
            writtenFileNames.insert(fileName)
            let url = folder.appendingPathComponent(fileName)
            try? frontMatter(for: entry).write(to: url, atomically: true, encoding: .utf8)
        }

        if let existingFiles = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
            for fileURL in existingFiles where fileURL.pathExtension.lowercased() == "md" && fileURL.lastPathComponent != indexFileName {
                if !writtenFileNames.contains(fileURL.lastPathComponent) {
                    try? FileManager.default.removeItem(at: fileURL)
                }
            }
        }

        let indexBody = entries
            .sorted { $0.createdAt < $1.createdAt }
            .map { "- [[\(stem(for: $0))]] — \($0.content.prefix(100))" }
            .joined(separator: "\n")
        let index = """
        # Memory

        Everything Odysseus/Copilot remembers about you, synced automatically from the app's Memory tab.

        \(indexBody)
        """
        try? index.write(to: folder.appendingPathComponent(indexFileName), atomically: true, encoding: .utf8)

        try? modelContext.save()
    }

    /// Stable, human-readable filename for an entry. Once assigned it's
    /// reused (via `vaultFileName`) so editing an entry's content doesn't
    /// rename its file out from under an open Obsidian note.
    private static func fileName(for entry: MemoryEntry) -> String {
        if !entry.vaultFileName.isEmpty { return entry.vaultFileName }
        var slug = entry.content
            .prefix(40)
            .lowercased()
            .replacingOccurrences(of: "[^a-z0-9]+", with: "-", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        if slug.isEmpty { slug = "memory" }
        let suffix = String(entry.id.prefix(8))
        return "\(slug)-\(suffix).md"
    }

    private static func stem(for entry: MemoryEntry) -> String {
        let name = fileName(for: entry)
        return name.hasSuffix(".md") ? String(name.dropLast(3)) : name
    }

    private static func frontMatter(for entry: MemoryEntry) -> String {
        """
        ---
        id: \(entry.id)
        created: \(ISO8601DateFormatter().string(from: entry.createdAt))
        source: \(entry.isAISaved ? "ai" : "manual")
        ---

        \(entry.content)
        """
    }
}

//
//  MemoryStore.swift
//  Odysseus
//
//  MemoryEntry (SwiftData) is the source of truth for the browsable/editable
//  list in the Memory tab. This keeps a plain-text cache in UserDefaults —
//  same pattern as WritingProfile — so the AI system prompts (which are
//  static/computed properties with no ModelContext access) can read it
//  synchronously. Call rebuild(context:) after any insert/delete/edit.
//
//  rebuild(context:) also mirrors every entry out to the connected Obsidian
//  vault (see MemoryVaultSync) — that's a no-op when no vault is connected.
//

import Foundation
import SwiftData

nonisolated enum MemoryStore {
    private static let cacheKey = "memory_brain_cache_v1"

    /// Appended to any AI system prompt so it actually remembers things
    /// across separate conversations, not just within one chat's history.
    static var contextInstruction: String {
        guard let cache = UserDefaults.standard.string(forKey: cacheKey), !cache.isEmpty else { return "" }
        return "\n\nThings you remember about the user from past conversations — use these naturally, don't just recite them:\n" + cache
    }

    @MainActor
    static func rebuild(context: ModelContext) {
        let entries = (try? context.fetch(FetchDescriptor<MemoryEntry>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        let text = entries.map { "- \($0.content)" }.joined(separator: "\n")
        UserDefaults.standard.set(text, forKey: cacheKey)
        MemoryVaultSync.pushToVault(entries: entries, modelContext: context)
    }
}

//
//  MemoryEntry.swift
//  Odysseus
//
//  A single fact the AI (Odysseus/Copilot) remembers about the user across
//  every future conversation — either saved automatically mid-chat or added
//  by hand here.
//
//  SwiftData stays the source of truth (see MemoryStore/MemoryVaultSync);
//  when an Obsidian vault is connected, every entry is also mirrored out as
//  a real .md file under <vault>/Memory/ so it's a browsable, editable
//  vault note too, not just an in-app list.
//

import Foundation
import SwiftData

@Model
final class MemoryEntry {
    var id: String = UUID().uuidString
    var content: String = ""
    var isAISaved: Bool = false
    var createdAt: Date = Date.now
    /// Filename this entry is mirrored to under <vault>/Memory/ once an
    /// Obsidian vault is connected (e.g. "started-new-job-3f9a21bc.md").
    /// Empty until first synced; stable across content edits.
    var vaultFileName: String = ""

    init(
        id: String = UUID().uuidString,
        content: String,
        isAISaved: Bool = false,
        createdAt: Date = .now,
        vaultFileName: String = ""
    ) {
        self.id = id
        self.content = content
        self.isAISaved = isAISaved
        self.createdAt = createdAt
        self.vaultFileName = vaultFileName
    }
}

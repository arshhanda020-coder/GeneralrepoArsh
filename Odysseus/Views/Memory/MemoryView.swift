//
//  MemoryView.swift
//  Odysseus
//
//  Everything Odysseus/Copilot remembers about you across every conversation —
//  browsable and editable, not a black box. AI-saved entries are flagged;
//  you can add your own or delete anything.
//

import SwiftUI
import SwiftData

struct MemoryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \MemoryEntry.createdAt, order: .reverse) private var entries: [MemoryEntry]
    @StateObject private var vault = ObsidianVaultManager.shared

    @State private var showingAdd = false
    @State private var editingEntry: MemoryEntry?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !entries.isEmpty {
                    MemoryNeuroCanvas(entries: entries) { entry in
                        editingEntry = entry
                    }
                    .frame(maxWidth: .infinity)
                }

                Text("This fills in on its own as you talk to Odysseus/Copilot — everything worth remembering gets saved here automatically and feeds back into every future conversation as context. Nothing to set up.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)

                vaultStatusRow

                if entries.isEmpty {
                    EmptyStateView(
                        icon: MindMapSection.memory.symbolName,
                        title: "Nothing yet",
                        message: "Just talk to Odysseus or Copilot normally and it'll start filling in here on its own. You can also add something yourself with +.",
                        tint: MindMapSection.memory.accentColor
                    )
                    .glassPanel(cornerRadius: 14)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            row(entry)
                        }
                    }
                    .glassPanel(cornerRadius: 10)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Memory")
        .sectionAssistantButton(.memory)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAdd = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAdd) {
            AddEditMemoryView(entry: nil)
        }
        .sheet(item: $editingEntry) { entry in
            AddEditMemoryView(entry: entry)
        }
    }

    private var vaultStatusRow: some View {
        HStack(spacing: 6) {
            Image(systemName: vault.isConnected ? "checkmark.circle.fill" : "folder.badge.questionmark")
                .font(.caption2)
                .foregroundStyle(vault.isConnected ? Theme.terminalGreen : Theme.dimText)
            Text(vault.isConnected
                 ? "Also synced as real notes in your Obsidian vault (\(vault.vaultName ?? "")/Memory/)."
                 : "Connect an Obsidian vault (Obsidian tab) to also keep these as real, editable notes.")
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
    }

    private func row(_ entry: MemoryEntry) -> some View {
        HStack(alignment: .top, spacing: 10) {
            if entry.isAISaved {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundStyle(MindMapSection.memory.accentColor)
                    .padding(.top, 2)
            }
            Text(entry.content)
                .font(.subheadline)
                .foregroundStyle(Theme.primaryText)
            Spacer()
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture { editingEntry = entry }
    }
}

#Preview {
    NavigationStack {
        MemoryView()
    }
    .modelContainer(for: [MemoryEntry.self], inMemory: true)
}

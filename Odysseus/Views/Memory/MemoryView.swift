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

                if entries.isEmpty {
                    Text("Nothing yet — just talk to Odysseus or Copilot normally and it'll start filling in here on its own. (You can also add something yourself with +, if you'd rather.)")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
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

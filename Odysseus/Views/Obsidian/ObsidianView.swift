//
//  ObsidianView.swift
//  Odysseus
//
//  Connects a real Obsidian vault (a folder of .md files, picked once via
//  the system folder picker) and caches its notes into SwiftData so they're
//  browsable offline and previewable elsewhere in the app (the "second
//  brain" glimpses the user asked for).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct ObsidianView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var vault = ObsidianVaultManager.shared
    @Query(sort: \ObsidianNote.modifiedAt, order: .reverse) private var notes: [ObsidianNote]

    @State private var showingFolderPicker = false
    @State private var selectedNote: ObsidianNote?
    @State private var showingDisconnectConfirmation = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusCard

                if notes.isEmpty && vault.isConnected {
                    Text(vault.isSyncing ? "Syncing…" : "No markdown notes found in this vault yet.")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.dimText)
                        .padding(.top, 8)
                } else if !notes.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            row(note)
                        }
                    }
                    .glassPanel(cornerRadius: 8)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Obsidian Vault")
        .inlineNavigationTitle()
        .fileImporter(isPresented: $showingFolderPicker, allowedContentTypes: [.folder]) { result in
            if case .success(let url) = result {
                vault.connect(url: url, modelContext: modelContext)
            }
        }
        .navigationDestination(item: $selectedNote) { note in
            ObsidianNoteDetailView(note: note)
        }
        .confirmationDialog("Disconnect this vault?", isPresented: $showingDisconnectConfirmation, titleVisibility: .visible) {
            Button("Disconnect", role: .destructive) {
                vault.disconnect(modelContext: modelContext)
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Cached notes will be removed from the app. Your vault on disk is untouched.")
        }
    }

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(vault.isConnected ? Theme.terminalGreen : Theme.dimText.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(vault.isConnected ? "VAULT · \(vault.vaultName ?? "")".uppercased() : "NO VAULT CONNECTED")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Theme.dimText)
            }

            if let lastSynced = vault.lastSyncedAt {
                Text("Last synced \(lastSynced.formatted(.relative(presentation: .named)))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.dimText)
            }

            if let error = vault.lastError {
                Text(error)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.negative)
            }

            HStack(spacing: 8) {
                if vault.isConnected {
                    Button {
                        vault.sync(modelContext: modelContext)
                    } label: {
                        Label(vault.isSyncing ? "SYNCING…" : "RESYNC", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(MindMapSection.obsidian.accentColor)
                    .disabled(vault.isSyncing)

                    Button(role: .destructive) {
                        showingDisconnectConfirmation = true
                    } label: {
                        Text("DISCONNECT")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                } else {
                    Button {
                        showingFolderPicker = true
                    } label: {
                        Label("CONNECT VAULT FOLDER", systemImage: "folder.badge.plus")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MindMapSection.obsidian.accentColor)
                }
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 8)
    }

    private func row(_ note: ObsidianNote) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(note.title)
                .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                .foregroundStyle(Theme.primaryText)
            if !note.excerpt.isEmpty {
                Text(note.excerpt)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(2)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { selectedNote = note }
    }
}

private struct ObsidianNoteDetailView: View {
    let note: ObsidianNote

    var body: some View {
        ScrollView {
            Text(note.content)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(Theme.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(note.title)
        .inlineNavigationTitle()
    }
}

#Preview {
    NavigationStack {
        ObsidianView()
    }
    .modelContainer(for: [ObsidianNote.self], inMemory: true)
}

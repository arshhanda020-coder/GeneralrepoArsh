//
//  NotesView.swift
//  Odysseus
//
//  Hub for notes that live outside the app: Google Docs (pulled read-only via
//  OAuth + the Docs API) and Notability exports (file-imported, since
//  Notability has no API). Obsidian gets its own dedicated section already —
//  this is everything else under the "docs and notes" umbrella.
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct NotesView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var googleAuth = GoogleDocsAuthManager.shared
    @Query(sort: \DocNote.modifiedAt, order: .reverse) private var allNotes: [DocNote]

    @State private var showingSettings = false
    @State private var showingFileImporter = false
    @State private var selectedNote: DocNote?
    @State private var googleDocs: [GoogleDocsService.DocSummary] = []
    @State private var isLoadingGoogleDocs = false
    @State private var statusMessage: String?
    @State private var importingDocID: String?

    private var notabilityNotes: [DocNote] { allNotes.filter { $0.source == .notability } }
    private var googleNotes: [DocNote] { allNotes.filter { $0.source == .googleDocs } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                googleDocsCard
                notabilityCard

                if !allNotes.isEmpty {
                    Text("IMPORTED NOTES")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(1)
                        .foregroundStyle(Theme.dimText)
                        .padding(.top, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(allNotes.enumerated()), id: \.element.id) { index, note in
                            if index > 0 { Divider().overlay(Theme.cardBorder) }
                            row(note)
                        }
                    }
                    .glassPanel(cornerRadius: 8)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Notes")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingSettings = true } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            GoogleDocsSettingsSheet()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.pdf, .rtf, .plainText, .text],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .navigationDestination(item: $selectedNote) { note in
            DocNoteDetailView(note: note)
        }
        .task { if googleAuth.isConnected { await refreshGoogleDocs() } }
    }

    private var googleDocsCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(googleAuth.isConnected ? Theme.terminalGreen : Theme.dimText.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(googleAuth.isConnected ? "GOOGLE DOCS · CONNECTED" : "GOOGLE DOCS · NOT CONNECTED")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Theme.dimText)
            }

            if let message = googleAuth.statusMessage ?? statusMessage {
                Text(message)
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Color(hex: "FF6B6B"))
            }

            if googleAuth.isConnected {
                HStack(spacing: 8) {
                    Button {
                        Task { await refreshGoogleDocs() }
                    } label: {
                        Label(isLoadingGoogleDocs ? "LOADING…" : "REFRESH LIST", systemImage: "arrow.triangle.2.circlepath")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                    .tint(MindMapSection.notes.accentColor)
                    .disabled(isLoadingGoogleDocs)

                    Button(role: .destructive) {
                        googleAuth.disconnect()
                        googleDocs = []
                    } label: {
                        Text("DISCONNECT")
                            .font(.system(.caption, design: .monospaced).weight(.semibold))
                    }
                    .buttonStyle(.bordered)
                }

                if !googleDocs.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(googleDocs.enumerated()), id: \.element.id) { index, doc in
                            if index > 0 { Divider().overlay(Theme.cardBorder) }
                            googleDocRow(doc)
                        }
                    }
                    .padding(.top, 4)
                } else if !isLoadingGoogleDocs {
                    Text("No Google Docs found.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.dimText)
                }
            } else {
                Button {
                    googleAuth.connect()
                } label: {
                    Label("CONNECT GOOGLE ACCOUNT", systemImage: "person.badge.key")
                        .font(.system(.caption, design: .monospaced).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.notes.accentColor)
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 8)
    }

    private func googleDocRow(_ doc: GoogleDocsService.DocSummary) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.name)
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("Edited \(doc.modifiedDate.formatted(.relative(presentation: .named)))")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            if importingDocID == doc.id {
                ProgressView().controlSize(.small)
            } else if googleNotes.contains(where: { $0.sourceIdentifier == doc.id }) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.terminalGreen)
            } else {
                Button {
                    Task { await importGoogleDoc(doc) }
                } label: {
                    Image(systemName: "square.and.arrow.down")
                }
                .buttonStyle(.plain)
                .foregroundStyle(MindMapSection.notes.accentColor)
            }
        }
        .padding(.vertical, 8)
    }

    private var notabilityCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Circle()
                    .fill(notabilityNotes.isEmpty ? Theme.dimText.opacity(0.5) : Theme.terminalGreen)
                    .frame(width: 6, height: 6)
                Text(notabilityNotes.isEmpty ? "NOTABILITY · NO IMPORTS" : "NOTABILITY · \(notabilityNotes.count) IMPORTED")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Theme.dimText)
            }

            Text("No live sync — Notability doesn't have one. Export a note (Share → PDF, RTF, or plain text) then import the file here.")
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.dimText)

            Button {
                showingFileImporter = true
            } label: {
                Label("IMPORT NOTABILITY EXPORT", systemImage: "doc.badge.plus")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(MindMapSection.notes.accentColor)
        }
        .padding(12)
        .glassPanel(cornerRadius: 8)
    }

    private func row(_ note: DocNote) -> some View {
        HStack(spacing: 10) {
            Image(systemName: note.source == .googleDocs ? "doc.text" : "pencil.and.scribble")
                .foregroundStyle(Theme.dimText)
                .frame(width: 16)
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
            Spacer(minLength: 0)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture { selectedNote = note }
    }

    private func refreshGoogleDocs() async {
        isLoadingGoogleDocs = true
        statusMessage = nil
        defer { isLoadingGoogleDocs = false }
        do {
            googleDocs = try await GoogleDocsService.shared.listDocs()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func importGoogleDoc(_ doc: GoogleDocsService.DocSummary) async {
        importingDocID = doc.id
        defer { importingDocID = nil }
        do {
            let content = try await GoogleDocsService.shared.fetchContent(documentID: doc.id)
            let excerpt = String(content.trimmingCharacters(in: .whitespacesAndNewlines).prefix(220))
            let docID = doc.id
            let existing = try? modelContext.fetch(FetchDescriptor<DocNote>(
                predicate: #Predicate { $0.sourceIdentifier == docID && $0.sourceRaw == "googleDocs" }
            ))
            if let note = existing?.first {
                note.title = doc.name
                note.content = content
                note.excerpt = excerpt
                note.modifiedAt = doc.modifiedDate
            } else {
                modelContext.insert(DocNote(
                    title: doc.name,
                    excerpt: excerpt,
                    content: content,
                    source: .googleDocs,
                    sourceIdentifier: doc.id,
                    modifiedAt: doc.modifiedDate
                ))
            }
            try? modelContext.save()
        } catch {
            statusMessage = error.localizedDescription
        }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            for url in urls {
                do {
                    try NotabilityImportService.importFile(at: url, modelContext: modelContext)
                } catch {
                    statusMessage = error.localizedDescription
                }
            }
        case .failure(let error):
            statusMessage = error.localizedDescription
        }
    }
}

private struct DocNoteDetailView: View {
    let note: DocNote

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text(note.source.label.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Theme.dimText)
                Text(note.content)
                    .font(.system(.body, design: .monospaced))
                    .foregroundStyle(Theme.primaryText)
            }
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
        NotesView()
    }
    .modelContainer(for: [DocNote.self], inMemory: true)
}

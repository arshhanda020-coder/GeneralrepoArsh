//
//  NotesSectionView.swift
//  Odysseus
//
//  Embeddable "Notes" widget — drop into Today, a Project, a School topic, or
//  a Subagent's detail screen to show/create freeform notes attached to that
//  specific place. Backed by the same `Note` model as the standalone Notes
//  hub; moving a note in or out of a context is just re-pointing
//  `note.context` via NoteMoveSheet, reachable from NoteEditSheet.
//
//  Today notes are checkable — that's the "little reminder" use case — every
//  other context just shows title + preview.
//

import SwiftUI
import SwiftData

struct NotesSectionView: View {
    let context: NoteContext
    var accentColor: Color = MindMapSection.notes.accentColor

    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]

    @State private var newNoteTitle = ""
    @State private var selectedNote: Note?
    @State private var drawingNote: Note?

    init(context: NoteContext, accentColor: Color = MindMapSection.notes.accentColor) {
        self.context = context
        self.accentColor = accentColor
        let typeRaw = context.typeRaw
        let recordID = context.recordID
        _notes = Query(
            filter: #Predicate<Note> { $0.contextTypeRaw == typeRaw && $0.contextID == recordID },
            sort: \Note.createdAt, order: .reverse
        )
    }

    private var isToday: Bool { context == .today }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("NOTES")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.dimText)

            HStack(spacing: 8) {
                TextField(isToday ? "Quick reminder…" : "Add a note", text: $newNoteTitle)
                    .padding(10)
                    .glassPanel(cornerRadius: 8)
                    .onSubmit(addNote)
                Button(action: addNote) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dimText : accentColor)
                }
                .buttonStyle(.plain)
                .disabled(newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                Button(action: addDrawing) {
                    Image(systemName: "pencil.tip.crop.circle.badge.plus")
                        .font(.title2)
                        .foregroundStyle(accentColor)
                }
                .buttonStyle(.plain)
            }

            if !notes.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        row(note)
                    }
                }
                .glassPanel(cornerRadius: 8)
            }
        }
        .sheet(item: $selectedNote) { note in
            NoteEditSheet(note: note, accentColor: accentColor)
        }
        .platformFullScreenCover(item: $drawingNote) { note in
            NoteDrawingSheet(note: note, accentColor: accentColor)
        }
    }

    private func row(_ note: Note) -> some View {
        HStack(spacing: 10) {
            if isToday {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        note.isDone.toggle()
                    }
                } label: {
                    Image(systemName: note.isDone ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(note.isDone ? accentColor : Theme.dimText)
                }
                .buttonStyle(.plain)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(note.title)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(note.isDone && isToday ? Theme.dimText : Theme.primaryText)
                    .strikethrough(note.isDone && isToday)
                if !note.content.isEmpty {
                    Text(note.content)
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                        .lineLimit(2)
                }
            }
            Spacer(minLength: 0)
            if note.drawingData != nil {
                Image(systemName: "pencil.and.scribble")
                    .font(.caption)
                    .foregroundStyle(accentColor)
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { selectedNote = note }
    }

    private func addNote() {
        let trimmed = newNoteTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        modelContext.insert(Note(title: trimmed, context: context))
        newNoteTitle = ""
    }

    /// Creates a blank note and opens straight into the drawing canvas —
    /// the "new page" quick action next to the plain text add button.
    private func addDrawing() {
        let note = Note(title: "Untitled Drawing", context: context)
        modelContext.insert(note)
        drawingNote = note
    }
}

/// Edit a freeform note's title/content, move it to a different context, or
/// delete it. Used both by `NotesSectionView` (embedded contexts) and the
/// standalone Notes hub.
struct NoteEditSheet: View {
    @Bindable var note: Note
    var accentColor: Color = MindMapSection.notes.accentColor

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var titleDraft: String
    @State private var contentDraft: String
    @State private var showingMove = false
    @State private var showingDeleteConfirmation = false
    @State private var showingDrawing = false

    init(note: Note, accentColor: Color = MindMapSection.notes.accentColor) {
        self.note = note
        self.accentColor = accentColor
        _titleDraft = State(initialValue: note.title)
        _contentDraft = State(initialValue: note.content)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("TITLE") {
                    TextField("Title", text: $titleDraft)
                }
                Section("NOTE") {
                    TextField("Write anything…", text: $contentDraft, axis: .vertical)
                        .lineLimit(6...20)
                }
                Section("DRAWING") {
                    Button {
                        showingDrawing = true
                    } label: {
                        HStack {
                            Label(
                                note.drawingData == nil ? "No drawing yet" : "Has a handwritten page",
                                systemImage: "pencil.and.scribble"
                            )
                            Spacer()
                            Text(note.drawingData == nil ? "Draw" : "Open")
                                .foregroundStyle(accentColor)
                        }
                    }
                    .foregroundStyle(Theme.primaryText)
                }
                Section {
                    Button {
                        showingMove = true
                    } label: {
                        HStack {
                            Label(note.context?.label ?? "Standalone", systemImage: note.context?.symbolName ?? "tray")
                            Spacer()
                            Text("Move")
                                .foregroundStyle(accentColor)
                        }
                    }
                    .foregroundStyle(Theme.primaryText)
                }
            }
            .navigationTitle("Note")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(titleDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                ToolbarItem(placement: .destructiveAction) {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Image(systemName: "trash")
                    }
                }
            }
            .confirmationDialog("Delete this note?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(note)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            }
            .sheet(isPresented: $showingMove) {
                NoteMoveSheet(current: note.context) { newContext in
                    note.context = newContext
                    note.updatedAt = .now
                }
            }
            .platformFullScreenCover(isPresented: $showingDrawing) {
                NoteDrawingSheet(note: note, accentColor: accentColor)
            }
        }
    }

    private func save() {
        let trimmedTitle = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        note.title = trimmedTitle
        note.content = contentDraft
        note.updatedAt = .now
        dismiss()
    }
}

#Preview {
    NotesSectionView(context: .today)
        .padding()
        .modelContainer(for: [Note.self], inMemory: true)
}

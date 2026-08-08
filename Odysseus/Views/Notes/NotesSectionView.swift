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
import PhotosUI

struct NotesSectionView: View {
    let context: NoteContext
    var accentColor: Color = MindMapSection.notes.accentColor

    @Environment(\.modelContext) private var modelContext
    @Query private var notes: [Note]

    @State private var newNoteTitle = ""
    @State private var selectedNote: Note?

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
            if let colorHex = note.colorHex {
                Circle()
                    .fill(Color(hex: colorHex))
                    .frame(width: 8, height: 8)
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
            if !note.imageDatas.isEmpty {
                Image(systemName: "photo")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
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
}

/// Edit a freeform note's title/content, move it to a different context,
/// pick a color, attach images, export it, or delete it. Used both by
/// `NotesSectionView` (embedded contexts) and the standalone Notes hub.
struct NoteEditSheet: View {
    @Bindable var note: Note
    var accentColor: Color = MindMapSection.notes.accentColor

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @State private var titleDraft: String
    @State private var contentDraft: String
    @State private var colorHexDraft: String?
    @State private var imageDatasDraft: [Data]
    @State private var showingMove = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var shareURL: URL?

    private static let colorOptions = ["5FB8A8", "D9695F", "D9A857", "5FCB8C", "4F8FA8", "8A7CA8", "6B8F5A", "C77DAE"]

    init(note: Note, accentColor: Color = MindMapSection.notes.accentColor) {
        self.note = note
        self.accentColor = accentColor
        _titleDraft = State(initialValue: note.title)
        _contentDraft = State(initialValue: note.content)
        _colorHexDraft = State(initialValue: note.colorHex)
        _imageDatasDraft = State(initialValue: note.imageDatas)
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
                Section("COLOR") {
                    colorPicker
                }
                Section("IMAGES") {
                    imagesPicker
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

                    Button {
                        exportPDF()
                    } label: {
                        Label("Export & Share…", systemImage: "square.and.arrow.up")
                    }
                    .foregroundStyle(accentColor)
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
            .sheet(item: Binding(
                get: { shareURL.map { IdentifiableURL(url: $0) } },
                set: { shareURL = $0?.url }
            )) { wrapped in
                ShareSheet(items: [wrapped.url])
            }
            .onChange(of: selectedPhotos) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    for item in newItems {
                        guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
                        let compressed = PlatformImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                        imageDatasDraft.append(compressed)
                    }
                    selectedPhotos = []
                }
            }
        }
    }

    private var colorPicker: some View {
        HStack {
            Circle()
                .strokeBorder(Theme.dimText, lineWidth: 1)
                .background(Circle().fill(Theme.background))
                .frame(width: 24, height: 24)
                .overlay {
                    if colorHexDraft == nil {
                        Image(systemName: "slash.circle").font(.caption2).foregroundStyle(Theme.dimText)
                    }
                }
                .overlay(Circle().stroke(.white, lineWidth: colorHexDraft == nil ? 2 : 0))
                .onTapGesture { colorHexDraft = nil }
            Spacer(minLength: 4)
            ForEach(Self.colorOptions, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(.white, lineWidth: colorHexDraft == hex ? 2 : 0))
                    .onTapGesture { colorHexDraft = hex }
            }
        }
    }

    private var imagesPicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !imageDatasDraft.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(imageDatasDraft.enumerated()), id: \.offset) { index, data in
                            if let image = PlatformImage(data: data) {
                                Image(platformImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .overlay(alignment: .topTrailing) {
                                        Button {
                                            imageDatasDraft.remove(at: index)
                                        } label: {
                                            Image(systemName: "xmark.circle.fill")
                                                .foregroundStyle(.white, .black.opacity(0.6))
                                        }
                                        .buttonStyle(.plain)
                                        .padding(3)
                                    }
                            }
                        }
                    }
                }
            }
            PhotosPicker(selection: $selectedPhotos, matching: .images) {
                Label(imageDatasDraft.isEmpty ? "Add photos" : "Add more photos", systemImage: "photo.badge.plus")
            }
        }
    }

    private func exportPDF() {
        let trimmedTitle = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmedTitle.isEmpty ? note.title : trimmedTitle
        let data = NoteExportGenerator.makePDF(
            title: title,
            content: contentDraft,
            colorHex: colorHexDraft,
            imageDatas: imageDatasDraft,
            updatedAt: .now,
            defaultColorHex: MindMapSection.notes.accentHex
        )
        let safeFileName = title.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(safeFileName).pdf")
        try? data.write(to: url)
        shareURL = url
    }

    private func save() {
        let trimmedTitle = titleDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return }
        note.title = trimmedTitle
        note.content = contentDraft
        note.colorHex = colorHexDraft
        note.imageDatas = imageDatasDraft
        note.updatedAt = .now
        dismiss()
    }
}

#Preview {
    NotesSectionView(context: .today)
        .padding()
        .modelContainer(for: [Note.self], inMemory: true)
}

//
//  AddEditLessonMaterialView.swift
//  Odysseus
//
//  Google Classroom–style material: a link, or an attached file (document,
//  slideshow, download).
//

import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct AddEditLessonMaterialView: View {
    let material: LessonMaterial?
    /// Only used when creating new material — it's added under this lesson.
    var presetLesson: Lesson?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var kind: MaterialKind = .link
    @State private var urlString = ""
    @State private var fileData: Data?
    @State private var fileName: String?
    @State private var notes = ""
    @State private var showingFileImporter = false
    @State private var importError: String?

    private var canSave: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return false }
        if kind == .link { return !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        return fileData != nil || !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Material") {
                    TextField("Title", text: $title)
                    Picker("Type", selection: $kind) {
                        ForEach(MaterialKind.allCases) { kind in
                            Label(kind.displayName, systemImage: kind.icon).tag(kind)
                        }
                    }
                }

                Section(kind == .link ? "Link" : "Source") {
                    if kind != .link {
                        Button {
                            showingFileImporter = true
                        } label: {
                            Label(fileName ?? "Choose a file", systemImage: "paperclip")
                        }
                        if let fileName {
                            Text(fileName).font(.caption).foregroundStyle(Theme.dimText)
                        }
                        Text("Or link out instead:")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    }
                    TextField("https://…", text: $urlString)
                        .platformKeyboardType(.url)
                        .autocorrectionDisabled()
                    if let importError {
                        Text(importError).font(.caption).foregroundStyle(Theme.negative)
                    }
                }

                Section("Notes") {
                    TextField("Anything else", text: $notes, axis: .vertical)
                        .lineLimit(2...5)
                }

                if material != nil {
                    Section {
                        Button("Delete material", role: .destructive) { deleteMaterial() }
                    }
                }
            }
            .navigationTitle(material == nil ? "New Material" : "Edit Material")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!canSave)
                }
            }
            .onAppear(perform: populateIfEditing)
            .fileImporter(isPresented: $showingFileImporter, allowedContentTypes: [.item], allowsMultipleSelection: false) { result in
                handleFileImport(result)
            }
        }
    }

    private func populateIfEditing() {
        guard let material else { return }
        title = material.title
        kind = material.kind
        urlString = material.urlString ?? ""
        fileData = material.fileData
        fileName = material.fileName
        notes = material.notes ?? ""
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            guard url.startAccessingSecurityScopedResource() else {
                importError = "Couldn't access that file."
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }
            do {
                fileData = try Data(contentsOf: url)
                fileName = url.lastPathComponent
                importError = nil
                if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    title = url.deletingPathExtension().lastPathComponent
                }
            } catch {
                importError = error.localizedDescription
            }
        case .failure(let error):
            importError = error.localizedDescription
        }
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedURL = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if let material {
            material.title = trimmedTitle
            material.kind = kind
            material.urlString = trimmedURL.isEmpty ? nil : trimmedURL
            material.fileData = fileData
            material.fileName = fileName
            material.notes = trimmedNotes.isEmpty ? nil : trimmedNotes
        } else {
            modelContext.insert(LessonMaterial(
                title: trimmedTitle,
                kind: kind,
                urlString: trimmedURL.isEmpty ? nil : trimmedURL,
                fileData: fileData,
                fileName: fileName,
                notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
                lesson: presetLesson
            ))
        }
        dismiss()
    }

    private func deleteMaterial() {
        if let material {
            modelContext.delete(material)
        }
        dismiss()
    }
}

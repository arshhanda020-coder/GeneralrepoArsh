//
//  LogStudySessionSheet.swift
//  Odysseus
//

import SwiftUI
import SwiftData
import PhotosUI

struct LogStudySessionSheet: View {
    let exam: Exam

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var note = ""
    @State private var subjectArea = "General"
    @State private var durationText = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var screenshotData: Data?

    private let actSubjects = ["General", "English", "Math", "Reading", "Science"]

    var body: some View {
        NavigationStack {
            Form {
                if exam.category == .act {
                    Section("Section") {
                        Picker("Section", selection: $subjectArea) {
                            ForEach(actSubjects, id: \.self) { subject in
                                Text(subject).tag(subject)
                            }
                        }
                    }
                }
                Section("Duration (minutes, optional)") {
                    TextField("e.g. 45", text: $durationText)
                        .platformKeyboardType(.numberPad)
                }
                Section("Session note (optional)") {
                    TextField("What did you study?", text: $note, axis: .vertical)
                        .lineLimit(2...5)
                }
                Section("Screenshot (optional)") {
                    if let screenshotData, let uiImage = PlatformImage(data: screenshotData) {
                        Image(platformImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(screenshotData == nil ? "Attach a screenshot" : "Replace screenshot", systemImage: "photo")
                    }
                    if screenshotData != nil {
                        Button("Remove screenshot", role: .destructive) {
                            self.screenshotData = nil
                            selectedPhoto = nil
                        }
                    }
                }
            }
            .navigationTitle("Log study session")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onSubmit { save() }
            .task(id: selectedPhoto) {
                await loadScreenshot()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func loadScreenshot() async {
        guard let selectedPhoto else { return }
        do {
            guard let data = try await selectedPhoto.loadTransferable(type: Data.self) else { return }
            screenshotData = PlatformImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
        } catch {
            // No usable image data — leave screenshotData untouched.
        }
    }

    private func save() {
        let trimmed = note.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(StudySession(
            date: .now,
            note: trimmed.isEmpty ? nil : trimmed,
            subjectArea: exam.category == .act ? subjectArea : nil,
            durationMinutes: Int(durationText),
            exam: exam,
            screenshotData: screenshotData
        ))
        dismiss()
    }
}

//
//  MealLogSheet.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData
import PhotosUI

struct MealLogSheet: View {
    let habit: Habit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    private var today: Date { Calendar.current.startOfDay(for: Date()) }

    private var existing: Completion? {
        habit.completions.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you have?") {
                    TextField("e.g. Oatmeal and eggs", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Photo") {
                    if let imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Label(imageData == nil ? "Add photo" : "Change photo", systemImage: "camera")
                    }
                    if imageData != nil {
                        Button("Remove photo", role: .destructive) {
                            imageData = nil
                            selectedPhoto = nil
                        }
                    }
                }

                if existing != nil {
                    Button("Remove log", role: .destructive) {
                        if let existing {
                            modelContext.delete(existing)
                        }
                        dismiss()
                    }
                }
            }
            .navigationTitle("\(habit.emoji) \(habit.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                        dismiss()
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                text = existing?.note ?? ""
                imageData = existing?.imageData
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = UIImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                    }
                }
            }
        }
        .presentationDetents([.large])
    }

    private func save() {
        if let existing {
            existing.note = text
            existing.imageData = imageData
        } else {
            let completion = Completion(date: today, note: text, imageData: imageData, habit: habit)
            modelContext.insert(completion)
        }
    }
}

//
//  LogWorkoutSheet.swift
//  Odysseus
//

import SwiftUI
import SwiftData
import PhotosUI

struct LogWorkoutSheet: View {
    var entry: WorkoutEntry?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \ProgressEntry.date, order: .reverse) private var progressEntries: [ProgressEntry]

    @State private var text: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?
    @State private var hoursText: String = ""
    @State private var minutesText: String = ""
    @State private var caloriesText: String = ""
    @State private var isEstimating = false
    @State private var estimateError: String?

    private var totalMinutes: Int? {
        let hours = Int(hoursText) ?? 0
        let minutes = Int(minutesText) ?? 0
        let total = hours * 60 + minutes
        return total > 0 ? total : nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you do?") {
                    TextField("e.g. 5k run, upper body lifting", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Duration") {
                    HStack {
                        Text("Hours")
                        Spacer()
                        TextField("0", text: $hoursText)
                            .platformKeyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    HStack {
                        Text("Minutes")
                        Spacer()
                        TextField("0", text: $minutesText)
                            .platformKeyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                }

                Section("Calories burned") {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $caloriesText)
                            .platformKeyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    Button {
                        estimateCalories()
                    } label: {
                        Label(isEstimating ? "Estimating…" : "Estimate with AI", systemImage: "sparkles")
                    }
                    .disabled(isEstimating || text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || totalMinutes == nil)

                    if totalMinutes == nil {
                        Text("Add a duration above so AI has something to estimate from.")
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                    if let estimateError {
                        Text(estimateError).font(.caption).foregroundStyle(Theme.negative)
                    }
                }

                Section("Photo") {
                    if let imageData, let uiImage = PlatformImage(data: imageData) {
                        Image(platformImage: uiImage)
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

                if entry != nil {
                    Button("Delete", role: .destructive) {
                        if let entry { modelContext.delete(entry) }
                        dismiss()
                    }
                }
            }
            .navigationTitle(entry == nil ? "Log Workout" : "Edit Workout")
            .inlineNavigationTitle()
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
                text = entry?.note ?? ""
                imageData = entry?.imageData
                caloriesText = entry?.caloriesBurned.map(String.init) ?? ""
                if let duration = entry?.durationMinutes {
                    hoursText = duration / 60 > 0 ? String(duration / 60) : ""
                    minutesText = duration % 60 > 0 ? String(duration % 60) : ""
                }
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = PlatformImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                    }
                }
            }
            .onSubmit {
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                save()
                dismiss()
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func estimateCalories() {
        guard let minutes = totalMinutes else { return }
        isEstimating = true
        estimateError = nil

        let weight = progressEntries.first(where: { $0.weight != nil })?.weight
        var statsLines: [String] = []
        if let weight { statsLines.append("Body weight: \(Int(weight)) lbs") }
        if let height = HealthProfile.heightInches { statsLines.append("Height: \(Int(height)) in") }
        if let age = HealthProfile.age { statsLines.append("Age: \(age)") }
        if let sex = HealthProfile.sex, sex != "Prefer not to say" { statsLines.append("Sex: \(sex)") }
        let statsBlock = statsLines.isEmpty ? "No body stats on file — use reasonable average adult assumptions." : statsLines.joined(separator: "\n")

        let prompt = """
        Estimate calories burned for this workout. Respond in EXACTLY this format, nothing else:
        CALORIES: <number only>

        Person's stats:
        \(statsBlock)

        Workout: \(text)
        Duration: \(minutes) minutes
        """

        Task {
            do {
                let response = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: imageData,
                    systemPrompt: "You are a fitness/exercise physiology estimator. Give your best reasonable estimate of calories burned given the person's stats, the activity, and duration — approximate is fine, always provide a number."
                )
                if let range = response.range(of: "CALORIES:", options: .caseInsensitive) {
                    let value = response[range.upperBound...].filter { $0.isNumber }
                    if !value.isEmpty { caloriesText = value }
                }
            } catch {
                estimateError = error.localizedDescription
            }
            isEstimating = false
        }
    }

    private func save() {
        if let entry {
            entry.note = text
            entry.imageData = imageData
            entry.durationMinutes = totalMinutes
            entry.caloriesBurned = Int(caloriesText)
        } else {
            let newEntry = WorkoutEntry(note: text, imageData: imageData, durationMinutes: totalMinutes, caloriesBurned: Int(caloriesText))
            modelContext.insert(newEntry)
        }
    }
}

//
//  LogWorkoutSheet.swift
//  Odysseus
//
//  Log a workout/activity: what you did, how intense it was, how long —
//  calories burned is never typed in, it's computed automatically (AI first,
//  falling back to a local MET-based formula if AI is unavailable) the
//  moment all three are filled in, so there's nothing to press.
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
    @State private var intensity: WorkoutIntensity?
    @State private var hoursText: String = ""
    @State private var minutesText: String = ""
    @State private var caloriesBurned: Int?
    @State private var isEstimateFallback = false
    @State private var isEstimating = false
    @State private var estimateError: String?
    @FocusState private var isDescriptionFocused: Bool

    private var totalMinutes: Int? {
        let hours = Int(hoursText) ?? 0
        let minutes = Int(minutesText) ?? 0
        let total = hours * 60 + minutes
        return total > 0 ? total : nil
    }

    private var readyToEstimate: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && intensity != nil && totalMinutes != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you do?") {
                    TextField("e.g. 5k run, upper body lifting, basketball", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($isDescriptionFocused)
                        .onChange(of: isDescriptionFocused) { wasFocused, isFocused in
                            if wasFocused, !isFocused { estimateIfReady() }
                        }
                }

                Section("Intensity") {
                    Picker("Intensity", selection: $intensity) {
                        Text("Select…").tag(WorkoutIntensity?.none)
                        ForEach(WorkoutIntensity.allCases) { level in
                            Text(level.label).tag(WorkoutIntensity?.some(level))
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .onChange(of: intensity) { _, _ in estimateIfReady() }
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
                    .onChange(of: hoursText) { _, _ in estimateIfReady() }
                    HStack {
                        Text("Minutes")
                        Spacer()
                        TextField("0", text: $minutesText)
                            .platformKeyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 60)
                    }
                    .onChange(of: minutesText) { _, _ in estimateIfReady() }
                }

                Section("Calories burned") {
                    if isEstimating {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Calculating…")
                                .font(.caption)
                                .foregroundStyle(Theme.dimText)
                        }
                    } else if let caloriesBurned {
                        HStack {
                            Text("\(caloriesBurned) cal")
                                .font(.subheadline.weight(.semibold).monospacedDigit())
                                .foregroundStyle(Theme.primaryText)
                            if isEstimateFallback {
                                Text("(rough estimate)")
                                    .font(.caption2)
                                    .foregroundStyle(Theme.dimText)
                            }
                            Spacer()
                        }
                    } else {
                        Text(readyToEstimate ? "Calculating…" : "Fill in what you did, intensity, and duration — this fills in on its own.")
                            .font(.caption)
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
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isEstimating)
                }
            }
            .onAppear {
                text = entry?.note ?? ""
                imageData = entry?.imageData
                intensity = entry?.intensity
                caloriesBurned = entry?.caloriesBurned
                isEstimateFallback = entry?.isEstimateFallback ?? false
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
        }
        .presentationDetents([.medium, .large])
    }

    /// Re-estimates whenever the three inputs are all filled in — recomputes
    /// on any later edit too (e.g. they change intensity after already
    /// getting a number), since there's no explicit "estimate" action to
    /// gate it behind anymore.
    private func estimateIfReady() {
        guard readyToEstimate, let minutes = totalMinutes, let intensity else { return }
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

        Activity: \(text)
        Intensity: \(intensity.label) (\(intensity.rawValue) of 5, where 1 = light and 5 = max effort)
        Duration: \(minutes) minutes
        """

        Task {
            do {
                let response = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: imageData,
                    systemPrompt: "You are a fitness/exercise physiology estimator. Give your best reasonable estimate of calories burned given the person's stats, the activity, intensity, and duration — approximate is fine, always provide a number."
                )
                if let range = response.range(of: "CALORIES:", options: .caseInsensitive) {
                    let value = response[range.upperBound...].filter { $0.isNumber }
                    if let parsed = Int(value) {
                        caloriesBurned = parsed
                        isEstimateFallback = false
                    } else {
                        fallBackToLocalEstimate(minutes: minutes, intensity: intensity, weight: weight)
                    }
                } else {
                    fallBackToLocalEstimate(minutes: minutes, intensity: intensity, weight: weight)
                }
            } catch {
                // AI unavailable (no key, offline, etc.) — never leave calories
                // blank, fall back to a local MET-based formula instead.
                fallBackToLocalEstimate(minutes: minutes, intensity: intensity, weight: weight)
            }
            isEstimating = false
        }
    }

    /// MET formula: calories = MET x weight(kg) x hours. Used whenever the AI
    /// estimate fails, so calories burned always gets a number.
    private func fallBackToLocalEstimate(minutes: Int, intensity: WorkoutIntensity, weight: Double?) {
        let weightKg = (weight ?? 160) * 0.453592 // default ~160lb adult if no Progress-tab weight yet
        let hours = Double(minutes) / 60
        caloriesBurned = max(1, Int(intensity.met * weightKg * hours))
        isEstimateFallback = true
        estimateError = nil
    }

    private func save() {
        if let entry {
            entry.note = text
            entry.imageData = imageData
            entry.durationMinutes = totalMinutes
            entry.caloriesBurned = caloriesBurned
            entry.intensity = intensity
            entry.isEstimateFallback = isEstimateFallback
        } else {
            let newEntry = WorkoutEntry(
                note: text,
                imageData: imageData,
                durationMinutes: totalMinutes,
                caloriesBurned: caloriesBurned,
                intensity: intensity,
                isEstimateFallback: isEstimateFallback
            )
            modelContext.insert(newEntry)
            NotificationManager.shared.notifyWorkoutLogged(note: text)
        }
        // A fresh entry just landed, so the "haven't logged a workout in a
        // while" nudge (if one was pending) is no longer accurate.
        NotificationManager.shared.cancelOneOff(identifier: "workout-nudge")
    }
}

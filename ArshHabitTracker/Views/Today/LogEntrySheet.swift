//
//  LogEntrySheet.swift
//  ArshHabitTracker
//
//  Generic note+photo logging sheet for any "logging type" habit category
//  (meals, workouts) — replaces the old meal-only MealLogSheet. Meals also
//  get manual macro entry plus an optional AI estimate from the photo.
//

import SwiftUI
import SwiftData
import PhotosUI

struct LogEntrySheet: View {
    let habit: Habit

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var isEstimating = false
    @State private var estimateError: String?

    private var today: Date { Calendar.current.startOfDay(for: Date()) }
    private var isMeal: Bool { habit.category == .meals }

    private var existing: Completion? {
        habit.completions.first { Calendar.current.isDate($0.date, inSameDayAs: today) }
    }

    private var promptText: String {
        habit.category == .workouts ? "What did you do?" : "What did you have?"
    }

    private var placeholderText: String {
        habit.category == .workouts ? "e.g. 5k run, 28 min" : "e.g. Oatmeal and eggs"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(promptText) {
                    TextField(placeholderText, text: $text, axis: .vertical)
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

                if isMeal {
                    Section("Macros") {
                        HStack {
                            Text("Calories")
                            Spacer()
                            TextField("0", text: $calories)
                                .keyboardType(.numberPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Protein (g)")
                            Spacer()
                            TextField("0", text: $protein)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Carbs (g)")
                            Spacer()
                            TextField("0", text: $carbs)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }
                        HStack {
                            Text("Fat (g)")
                            Spacer()
                            TextField("0", text: $fat)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 80)
                        }

                        Button {
                            estimateWithAI()
                        } label: {
                            Label(isEstimating ? "Estimating…" : "Estimate with AI", systemImage: "sparkles")
                        }
                        .disabled(isEstimating || imageData == nil)

                        if let estimateError {
                            Text(estimateError).font(.caption).foregroundStyle(Color(hex: "FF6B6B"))
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
                calories = existing?.calories.map(String.init) ?? ""
                protein = existing?.proteinGrams.map { String(format: "%.0f", $0) } ?? ""
                carbs = existing?.carbsGrams.map { String(format: "%.0f", $0) } ?? ""
                fat = existing?.fatGrams.map { String(format: "%.0f", $0) } ?? ""
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

    private func estimateWithAI() {
        guard let imageData else { return }
        isEstimating = true
        estimateError = nil
        Task {
            do {
                let response = try await AnthropicService.shared.askAboutImage(
                    prompt: "Estimate the nutrition for this meal. Respond in EXACTLY this format, nothing else:\nCALORIES: <number>\nPROTEIN: <grams, number only>\nCARBS: <grams, number only>\nFAT: <grams, number only>",
                    imageData: imageData,
                    systemPrompt: "You are a nutrition estimator. Give your best reasonable estimate from the photo — approximate is fine, always provide numbers."
                )
                applyEstimate(response)
            } catch {
                estimateError = error.localizedDescription
            }
            isEstimating = false
        }
    }

    private func applyEstimate(_ text: String) {
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            let value = parts[1].filter { $0.isNumber || $0 == "." }
            switch parts[0].uppercased() {
            case "CALORIES": calories = value
            case "PROTEIN": protein = value
            case "CARBS": carbs = value
            case "FAT": fat = value
            default: break
            }
        }
    }

    private func save() {
        let caloriesValue = Int(calories)
        let proteinValue = Double(protein)
        let carbsValue = Double(carbs)
        let fatValue = Double(fat)

        if let existing {
            existing.note = text
            existing.imageData = imageData
            existing.calories = caloriesValue
            existing.proteinGrams = proteinValue
            existing.carbsGrams = carbsValue
            existing.fatGrams = fatValue
        } else {
            let completion = Completion(
                date: today,
                note: text,
                imageData: imageData,
                calories: caloriesValue,
                proteinGrams: proteinValue,
                carbsGrams: carbsValue,
                fatGrams: fatValue,
                habit: habit
            )
            modelContext.insert(completion)
        }
    }
}

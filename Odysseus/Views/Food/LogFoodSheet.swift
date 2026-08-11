//
//  LogFoodSheet.swift
//  Odysseus
//
//  Logs one meal/snack at a time — flat entries, so breakfast/lunch/dinner
//  and snacks all just get logged as they happen, no predefined template.
//

import SwiftUI
import SwiftData
import PhotosUI

struct LogFoodSheet: View {
    var entry: FoodEntry?
    /// Which meal section this was opened from (or the time-of-day guess for
    /// a generic add) — only used to seed a new entry, ignored when editing.
    var defaultMealType: MealType = .forCurrentTime()

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text: String = ""
    @State private var mealType: MealType = .snack
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var imageData: Data?

    @State private var calories: String = ""
    @State private var protein: String = ""
    @State private var carbs: String = ""
    @State private var fat: String = ""
    @State private var isEstimating = false
    @State private var estimateError: String?
    @State private var showingScanner = false
    @State private var isLookingUpBarcode = false
    @State private var scanError: String?
    @FocusState private var isDescriptionFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("What did you have?") {
                    TextField("e.g. Oatmeal and eggs", text: $text, axis: .vertical)
                        .lineLimit(3...6)
                        .focused($isDescriptionFocused)
                        .onChange(of: isDescriptionFocused) { wasFocused, isFocused in
                            // Auto-estimate from the description once they're done typing.
                            // Fires whether or not a photo is already attached — if a photo
                            // landed first, this lets a follow-up description refine that
                            // estimate. Gated on calories.isEmpty so it doesn't fire on every
                            // re-focus of an already-estimated/filled entry.
                            guard wasFocused, !isFocused, calories.isEmpty,
                                  !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                            estimateWithAI()
                        }

                    Picker("Meal", selection: $mealType) {
                        ForEach(MealType.allCases) { meal in
                            Label(meal.rawValue, systemImage: meal.symbolName).tag(meal)
                        }
                    }
                    .pickerStyle(.segmented)
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

                Section("Macros") {
                    HStack {
                        Text("Calories")
                        Spacer()
                        TextField("0", text: $calories)
                            .platformKeyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Protein (g)")
                        Spacer()
                        TextField("0", text: $protein)
                            .platformKeyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Carbs (g)")
                        Spacer()
                        TextField("0", text: $carbs)
                            .platformKeyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }
                    HStack {
                        Text("Fat (g)")
                        Spacer()
                        TextField("0", text: $fat)
                            .platformKeyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 80)
                    }

                    if isEstimating {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text(imageData != nil ? "Analyzing photo…" : "Estimating from description…")
                                .font(.caption)
                                .foregroundStyle(Theme.dimText)
                        }
                    }
                    if let estimateError {
                        Text(estimateError).font(.caption).foregroundStyle(Theme.negative)
                    }

                    #if os(iOS)
                    Button {
                        showingScanner = true
                    } label: {
                        Label(isLookingUpBarcode ? "Looking up…" : "Scan Barcode", systemImage: "barcode.viewfinder")
                    }
                    .disabled(isLookingUpBarcode)
                    #endif

                    if let scanError {
                        Text(scanError).font(.caption).foregroundStyle(Theme.negative)
                    }
                }

                if entry != nil {
                    Button("Delete", role: .destructive) {
                        if let entry { modelContext.delete(entry) }
                        dismiss()
                    }
                }
            }
            .navigationTitle(entry == nil ? "Log Meal" : "Edit Meal")
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
                mealType = entry?.mealType ?? defaultMealType
                imageData = entry?.imageData
                calories = entry?.calories.map(String.init) ?? ""
                protein = entry?.proteinGrams.map { String(format: "%.0f", $0) } ?? ""
                carbs = entry?.carbsGrams.map { String(format: "%.0f", $0) } ?? ""
                fat = entry?.fatGrams.map { String(format: "%.0f", $0) } ?? ""
            }
            .onChange(of: selectedPhoto) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        imageData = PlatformImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                        // A photo is the strongest signal we have — estimate the moment it lands,
                        // no button press needed.
                        estimateWithAI()
                    }
                }
            }
            .onSubmit {
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                save()
                dismiss()
            }
        }
        .presentationDetents([.large])
        #if os(iOS)
        .platformFullScreenCover(isPresented: $showingScanner) {
            ZStack(alignment: .topTrailing) {
                BarcodeScannerView(
                    onScan: { barcode in
                        showingScanner = false
                        lookUp(barcode: barcode)
                    },
                    onCancel: { showingScanner = false }
                )
                .ignoresSafeArea()

                Button {
                    showingScanner = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title)
                        .foregroundStyle(.white, .black.opacity(0.6))
                }
                .padding()
            }
        }
        #endif
    }

    private func lookUp(barcode: String) {
        isLookingUpBarcode = true
        scanError = nil
        Task {
            do {
                let nutrition = try await BarcodeLookupService.shared.lookup(barcode: barcode)
                if let cal = nutrition.calories { calories = String(cal) }
                if let proteinValue = nutrition.proteinGrams { protein = String(format: "%.0f", proteinValue) }
                if let carbsValue = nutrition.carbsGrams { carbs = String(format: "%.0f", carbsValue) }
                if let fatValue = nutrition.fatGrams { fat = String(format: "%.0f", fatValue) }
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, let name = nutrition.productName {
                    text = name
                }
                if nutrition.isPer100g {
                    scanError = "No serving size on file — these are per 100g, adjust for your actual portion."
                }
            } catch {
                scanError = error.localizedDescription
            }
            isLookingUpBarcode = false
        }
    }

    /// Runs automatically — off a freshly-added photo, or off the typed
    /// description once they stop editing it. When both a photo and a
    /// description are present, both are handed to the AI together (the
    /// description as context alongside the image) rather than picking one
    /// and discarding the other — a caption like "no dressing" or "half
    /// portion" can materially change the estimate a photo alone would give.
    private func estimateWithAI() {
        let hasPhoto = imageData != nil
        let description = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard hasPhoto || !description.isEmpty else { return }
        isEstimating = true
        estimateError = nil
        let restaurantNote = "If this names or clearly implies a specific restaurant/chain (e.g. Chipotle, Starbucks, Subway, McDonald's, Panera) and its menu items/ingredients (e.g. \"double chicken\", \"brown rice\", \"black beans\", \"queso\"), use your knowledge of that chain's actual published nutrition info per item/portion and add them up precisely — don't fall back to a generic guess when you know the real numbers. Otherwise, estimate as accurately as you reasonably can."
        let prompt: String
        if hasPhoto, !description.isEmpty {
            // Both signals available — the description often carries details
            // (portion size, missing/added ingredients, brand) a photo can't show.
            prompt = "Look closely at this meal photo, and combine what you see with the person's own description of it — treat their words as authoritative for anything the photo can't show (exact portion, ingredients left out or added, etc.), and use the photo to sharpen what's ambiguous in the description. Respond in EXACTLY this format, nothing else:\nDESCRIPTION: <a real, specific description of what the food actually is, reconciling the photo and their words>\nCALORIES: <number>\nPROTEIN: <grams, number only>\nCARBS: <grams, number only>\nFAT: <grams, number only>\n\nTheir description: \(description)\n\n\(restaurantNote)"
        } else if hasPhoto {
            prompt = "Look closely at this meal photo. Respond in EXACTLY this format, nothing else:\nDESCRIPTION: <a real, specific description of what the food actually is — name the dish/ingredients you can identify, not generic filler>\nCALORIES: <number>\nPROTEIN: <grams, number only>\nCARBS: <grams, number only>\nFAT: <grams, number only>\n\n\(restaurantNote)"
        } else {
            prompt = "Estimate nutrition for this meal from its description. Respond in EXACTLY this format, nothing else:\nCALORIES: <number>\nPROTEIN: <grams, number only>\nCARBS: <grams, number only>\nFAT: <grams, number only>\n\nMeal: \(description)\n\n\(restaurantNote)"
        }
        Task {
            do {
                let response = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: imageData,
                    systemPrompt: "You are a nutrition estimator with sharp food-recognition skills and deep knowledge of chain-restaurant published nutrition data. Actually identify what's in the photo or description — specific dishes/ingredients, not vague guesses — then give your best, most accurate nutrition estimate. Approximate numbers are fine when you truly don't know, but always provide them."
                )
                applyEstimate(response)
            } catch {
                estimateError = error.localizedDescription
            }
            isEstimating = false
        }
    }

    private func applyEstimate(_ responseText: String) {
        for line in responseText.split(separator: "\n") {
            let parts = line.split(separator: ":", maxSplits: 1).map { $0.trimmingCharacters(in: .whitespaces) }
            guard parts.count == 2 else { continue }
            switch parts[0].uppercased() {
            case "DESCRIPTION":
                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    text = parts[1]
                }
            case "CALORIES": calories = parts[1].filter { $0.isNumber || $0 == "." }
            case "PROTEIN": protein = parts[1].filter { $0.isNumber || $0 == "." }
            case "CARBS": carbs = parts[1].filter { $0.isNumber || $0 == "." }
            case "FAT": fat = parts[1].filter { $0.isNumber || $0 == "." }
            default: break
            }
        }
    }

    private func save() {
        let caloriesValue = Int(calories)
        let proteinValue = Double(protein)
        let carbsValue = Double(carbs)
        let fatValue = Double(fat)

        if let entry {
            entry.note = text
            entry.mealType = mealType
            entry.imageData = imageData
            entry.calories = caloriesValue
            entry.proteinGrams = proteinValue
            entry.carbsGrams = carbsValue
            entry.fatGrams = fatValue
        } else {
            let newEntry = FoodEntry(
                note: text,
                imageData: imageData,
                calories: caloriesValue,
                proteinGrams: proteinValue,
                carbsGrams: carbsValue,
                fatGrams: fatValue,
                mealType: mealType
            )
            modelContext.insert(newEntry)
            NotificationManager.shared.notifyFoodLogged(note: text)
        }
        // A same-day entry just landed, so the "you forgot to log food"
        // nudge (if one was pending) is no longer accurate.
        NotificationManager.shared.cancelOneOff(identifier: "food-nudge")
    }
}

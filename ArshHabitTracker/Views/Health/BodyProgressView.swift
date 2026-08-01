//
//  BodyProgressView.swift
//  ArshHabitTracker
//
//  Daily photo + weight check-in, a one-time height/age profile, and an
//  AI-narrated monthly report built from the weight trend (not from
//  comparing photos directly — that's not something AI can reliably judge).
//

import SwiftUI
import SwiftData
import PhotosUI

struct BodyProgressView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ProgressEntry.date, order: .reverse) private var entries: [ProgressEntry]
    @Query(sort: \MonthlyReport.generatedAt, order: .reverse) private var reports: [MonthlyReport]

    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoData: Data?
    @State private var weightText = ""
    @State private var heightText = String(HealthProfile.heightInches.map { String(format: "%.0f", $0) } ?? "")
    @State private var ageText = String(HealthProfile.age.map(String.init) ?? "")
    @State private var isGeneratingReport = false
    @State private var reportError: String?

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var todaysEntry: ProgressEntry? { entries.first { Calendar.current.isDate($0.date, inSameDayAs: today) } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            checkInCard
            profileCard
            reportsSection
            if entries.count > 1 {
                historySection
            }
        }
        .onAppear(perform: populateToday)
        .onChange(of: selectedPhoto) { _, newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self) {
                    photoData = UIImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                }
            }
        }
    }

    private var checkInCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TODAY'S CHECK-IN")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                if let photoData, let uiImage = UIImage(data: photoData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    Label(photoData == nil ? "Add today's photo" : "Change photo", systemImage: "camera")
                }

                HStack {
                    Text("Weight")
                    Spacer()
                    TextField("lbs", text: $weightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                }

                Button {
                    saveCheckIn()
                } label: {
                    Text("Save check-in")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.health.accentColor)
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private var profileCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROFILE")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(spacing: 10) {
                HStack {
                    Text("Height (in)")
                    Spacer()
                    TextField("in", text: $heightText)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: heightText) { _, value in HealthProfile.heightInches = Double(value) }
                }
                HStack {
                    Text("Age")
                    Spacer()
                    TextField("age", text: $ageText)
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 80)
                        .onChange(of: ageText) { _, value in HealthProfile.age = Int(value) }
                }
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private var reportsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("MONTHLY REPORT")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            Button {
                generateReport()
            } label: {
                Label(isGeneratingReport ? "Generating…" : "Generate report for the last 30 days", systemImage: "chart.xyaxis.line")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(MindMapSection.health.accentColor)
            .disabled(isGeneratingReport)

            if let reportError {
                Text(reportError).font(.caption).foregroundStyle(Color(hex: "C0605C"))
            }

            ForEach(reports) { report in
                reportCard(report)
            }
        }
    }

    private func reportCard(_ report: MonthlyReport) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(report.periodStart.formatted(.dateTime.month(.abbreviated).day()) + " – " + report.periodEnd.formatted(.dateTime.month(.abbreviated).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                Spacer()
                if let start = report.startWeight, let end = report.endWeight {
                    let change = end - start
                    Text(String(format: "%+.1f lbs", change))
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .foregroundStyle(change <= 0 ? Theme.terminalGreen : Theme.terminalAmber)
                }
            }
            Text(report.summaryText)
                .font(.caption)
                .foregroundStyle(Theme.dimText)
        }
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HISTORY")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(entries) { entry in
                        VStack(spacing: 4) {
                            if let data = entry.photoData, let uiImage = UIImage(data: data) {
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 70, height: 90)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Theme.card)
                                    .frame(width: 70, height: 90)
                            }
                            if let weight = entry.weight {
                                Text(String(format: "%.0f", weight))
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(.white)
                            }
                            Text(entry.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2)
                                .foregroundStyle(Theme.dimText)
                        }
                    }
                }
            }
        }
    }

    private func populateToday() {
        guard let todaysEntry else { return }
        photoData = todaysEntry.photoData
        weightText = todaysEntry.weight.map { String(format: "%.1f", $0) } ?? ""
    }

    private func saveCheckIn() {
        let weight = Double(weightText)
        if let existing = todaysEntry {
            existing.weight = weight
            existing.photoData = photoData
        } else {
            modelContext.insert(ProgressEntry(date: today, weight: weight, photoData: photoData))
        }
    }

    private func generateReport() {
        isGeneratingReport = true
        reportError = nil
        let periodStart = Calendar.current.date(byAdding: .day, value: -30, to: today) ?? today
        let inRange = entries.filter { $0.date >= periodStart }.sorted { $0.date < $1.date }

        guard let first = inRange.first, let last = inRange.last, inRange.count >= 2 else {
            reportError = "Log check-ins on at least two different days in the last 30 to generate a report."
            isGeneratingReport = false
            return
        }

        let weighedEntries = inRange.compactMap { $0.weight }
        let startWeight = first.weight
        let endWeight = last.weight
        let prompt = """
        Write a short (3-4 sentence), encouraging progress summary for a health/fitness journal based on this data:
        Check-ins logged: \(inRange.count) over \(Calendar.current.dateComponents([.day], from: periodStart, to: today).day ?? 30) days.
        Weight at start of period: \(startWeight.map { String(format: "%.1f lbs", $0) } ?? "not logged")
        Weight at end of period: \(endWeight.map { String(format: "%.1f lbs", $0) } ?? "not logged")
        All logged weights in the period: \(weighedEntries.map { String(format: "%.1f", $0) }.joined(separator: ", "))
        Focus on the trend and consistency, not exact body-fat numbers you can't know. Be honest but supportive.
        """

        Task {
            do {
                let summary = try await AISettings.currentService.draft(prompt: prompt)
                let report = MonthlyReport(
                    periodStart: periodStart,
                    periodEnd: today,
                    startWeight: startWeight,
                    endWeight: endWeight,
                    summaryText: summary
                )
                modelContext.insert(report)
            } catch {
                reportError = error.localizedDescription
            }
            isGeneratingReport = false
        }
    }
}

#Preview {
    BodyProgressView()
        .modelContainer(for: [ProgressEntry.self, MonthlyReport.self], inMemory: true)
}

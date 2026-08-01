//
//  ActivityView.swift
//  ArshHabitTracker
//
//  Time an activity (basketball, a run, whatever), stop it, answer a couple
//  of quick questions, and AI estimates the calories burned from the
//  duration + those answers.
//

import SwiftUI
import SwiftData

struct ActivityView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ActivitySession.createdAt, order: .reverse) private var sessions: [ActivitySession]

    @State private var activityName = ""
    @State private var isRunning = false
    @State private var startDate: Date?
    @State private var pendingDuration: Int?
    @State private var showingQuestionnaire = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            stopwatchCard

            if !sessions.isEmpty {
                historySection
            }
        }
        .sheet(isPresented: $showingQuestionnaire) {
            ActivityQuestionnaireSheet(
                activityName: activityName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Activity" : activityName,
                startedAt: startDate ?? .now,
                durationSeconds: pendingDuration ?? 0
            )
        }
    }

    private var stopwatchCard: some View {
        VStack(spacing: 14) {
            TextField("What are you doing? (basketball, running, lifting, etc.)", text: $activityName)
                .padding(10)
                .background(Theme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
                .disabled(isRunning)

            if isRunning, let startDate {
                TimelineView(.periodic(from: startDate, by: 1)) { context in
                    Text(formatted(elapsed: context.date.timeIntervalSince(startDate)))
                        .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                        .foregroundStyle(.white)
                }
            } else {
                Text("00:00")
                    .font(.system(.largeTitle, design: .monospaced).weight(.bold))
                    .foregroundStyle(Theme.dimText)
            }

            Button {
                toggle()
            } label: {
                Label(isRunning ? "Stop" : "Start", systemImage: isRunning ? "stop.fill" : "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isRunning ? Color(hex: "C0605C") : MindMapSection.health.accentColor)
        }
        .padding(14)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private var historySection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("SESSIONS")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(spacing: 0) {
                ForEach(Array(sessions.prefix(30).enumerated()), id: \.element.id) { index, session in
                    if index > 0 { Divider().overlay(Theme.cardBorder) }
                    sessionRow(session)
                }
            }
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private func sessionRow(_ session: ActivitySession) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(session.activityName)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.white)
                Text("\(formatted(elapsed: Double(session.durationSeconds))) · \(session.startedAt.formatted(.dateTime.month(.abbreviated).day()))")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            if let calories = session.estimatedCalories {
                Text("\(calories) cal")
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundStyle(MindMapSection.health.accentColor)
            }
        }
        .padding(10)
    }

    private func toggle() {
        if isRunning {
            let start = startDate ?? .now
            pendingDuration = max(1, Int(Date().timeIntervalSince(start)))
            isRunning = false
            showingQuestionnaire = true
        } else {
            startDate = .now
            isRunning = true
        }
    }

    private func formatted(elapsed: TimeInterval) -> String {
        let total = Int(elapsed)
        let minutes = total / 60
        let seconds = total % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

private struct ActivityQuestionnaireSheet: View {
    let activityName: String
    let startedAt: Date
    let durationSeconds: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var intensity: Double = 3
    @State private var sweatLevel: Double = 3
    @State private var isEstimating = false
    @State private var errorMessage: String?

    private let intensityLabels = ["Light", "Easy", "Moderate", "Hard", "Max effort"]
    private let sweatLabels = ["Barely", "A little", "Noticeable", "A lot", "Drenched"]

    var body: some View {
        NavigationStack {
            Form {
                Section("How was it?") {
                    VStack(alignment: .leading) {
                        Text("Intensity: \(intensityLabels[Int(intensity) - 1])")
                        Slider(value: $intensity, in: 1...5, step: 1)
                    }
                    VStack(alignment: .leading) {
                        Text("Sweating: \(sweatLabels[Int(sweatLevel) - 1])")
                        Slider(value: $sweatLevel, in: 1...5, step: 1)
                    }
                }
                if let errorMessage {
                    Section {
                        Text(errorMessage).font(.caption).foregroundStyle(Color(hex: "C0605C"))
                    }
                }
            }
            .navigationTitle(activityName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        estimateAndSave()
                    } label: {
                        Text(isEstimating ? "Saving…" : "Save")
                    }
                    .disabled(isEstimating)
                }
            }
        }
    }

    private func estimateAndSave() {
        isEstimating = true
        errorMessage = nil
        let minutes = max(1, durationSeconds / 60)
        let prompt = """
        Estimate calories burned for this activity session. Respond in EXACTLY this format, nothing else:
        CALORIES: <number>

        Activity: \(activityName)
        Duration: \(minutes) minutes
        Intensity (1=light, 5=max effort): \(Int(intensity))
        Sweating (1=barely, 5=drenched): \(Int(sweatLevel))
        """
        Task {
            do {
                let response = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: nil,
                    systemPrompt: "You are a fitness calorie estimator. Give your best reasonable estimate — approximate is fine, always provide a number."
                )
                let calories = Int(response.split(separator: ":").last?.trimmingCharacters(in: .whitespacesAndNewlines).filter { $0.isNumber } ?? "")
                let session = ActivitySession(
                    activityName: activityName,
                    startedAt: startedAt,
                    durationSeconds: durationSeconds,
                    intensity: Int(intensity),
                    sweatLevel: Int(sweatLevel),
                    estimatedCalories: calories
                )
                modelContext.insert(session)
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isEstimating = false
        }
    }
}

#Preview {
    ActivityView()
        .modelContainer(for: [ActivitySession.self], inMemory: true)
}

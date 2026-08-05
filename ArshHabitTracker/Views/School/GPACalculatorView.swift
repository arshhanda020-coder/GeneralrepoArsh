//
//  GPACalculatorView.swift
//  ArshHabitTracker
//
//  Nothing is assumed here — the user supplies their own grading scale, their
//  own honors/AP bonus, and their own grades, since these vary a lot by school.
//

import SwiftUI
import SwiftData

struct GPACalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GradeScaleEntry.sortIndex) private var scaleEntries: [GradeScaleEntry]
    @Query(sort: \GradeEntry.createdAt, order: .reverse) private var gradeEntries: [GradeEntry]

    @State private var newScaleLabel = ""
    @State private var newScalePoints = ""
    @State private var honorsBonus: Double = GPASettings.honorsBonus
    @State private var showingAddGrade = false
    @State private var editingGrade: GradeEntry?

    private func scalePoints(for label: String) -> Double? {
        scaleEntries.first { $0.label.caseInsensitiveCompare(label) == .orderedSame }?.points
    }

    private func gpa(weighted: Bool) -> Double? {
        let scored = gradeEntries.compactMap { entry -> (points: Double, credits: Double)? in
            guard let base = scalePoints(for: entry.gradeLabel) else { return nil }
            let bonus = (weighted && entry.isWeighted) ? honorsBonus : 0
            return (base + bonus, entry.credits)
        }
        let totalCredits = scored.reduce(0) { $0 + $1.credits }
        guard totalCredits > 0 else { return nil }
        let sum = scored.reduce(0) { $0 + $1.points * $1.credits }
        return sum / totalCredits
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                gpaSummary
                scaleSection
                bonusSection
                gradesSection
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("GPA Calculator")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddGrade = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAddGrade) {
            AddEditGradeEntryView(entry: nil)
        }
        .sheet(item: $editingGrade) { entry in
            AddEditGradeEntryView(entry: entry)
        }
    }

    private var gpaSummary: some View {
        HStack(spacing: 12) {
            gpaStat("UNWEIGHTED", gpa(weighted: false))
            gpaStat("WEIGHTED", gpa(weighted: true))
        }
    }

    private func gpaStat(_ label: String, _ value: Double?) -> some View {
        VStack(spacing: 2) {
            Text(value.map { String(format: "%.2f", $0) } ?? "—")
                .font(.title.weight(.heavy).monospacedDigit())
                .foregroundStyle(Theme.primaryText)
            Text(label)
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    // MARK: - Scale

    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR GRADING SCALE")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            HStack(spacing: 8) {
                TextField("Grade (e.g. A, B+)", text: $newScaleLabel)
                    .padding(8)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
                TextField("Points (e.g. 4.0)", text: $newScalePoints)
                    .keyboardType(.decimalPad)
                    .padding(8)
                    .background(Theme.card)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Theme.cardBorder, lineWidth: 1))
                Button(action: addScaleEntry) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canAddScale ? MindMapSection.school.accentColor : Theme.dimText)
                }
                .buttonStyle(.plain)
                .disabled(!canAddScale)
            }

            if scaleEntries.isEmpty {
                Text("Add your school's grade-to-point scale — e.g. A = 4.0, A- = 3.7, B+ = 3.3.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(scaleEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        HStack {
                            Text(entry.label).font(.subheadline.weight(.medium)).foregroundStyle(Theme.primaryText)
                            Spacer()
                            Text(String(format: "%.2f", entry.points)).font(.caption.monospacedDigit()).foregroundStyle(Theme.dimText)
                            Button {
                                modelContext.delete(entry)
                            } label: {
                                Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.dimText)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(10)
                    }
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
            }
        }
    }

    private var canAddScale: Bool {
        !newScaleLabel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && Double(newScalePoints) != nil
    }

    private func addScaleEntry() {
        guard let points = Double(newScalePoints) else { return }
        let label = newScaleLabel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !label.isEmpty else { return }
        let nextIndex = (scaleEntries.map(\.sortIndex).max() ?? -1) + 1
        modelContext.insert(GradeScaleEntry(label: label, points: points, sortIndex: nextIndex))
        newScaleLabel = ""
        newScalePoints = ""
    }

    // MARK: - Bonus

    private var bonusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("HONORS/AP BONUS")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            HStack {
                Text("Added to weighted GPA for Honors/AP courses")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                TextField("1.0", value: Binding(
                    get: { honorsBonus },
                    set: { honorsBonus = $0; GPASettings.honorsBonus = $0 }
                ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 60)
            }
            .padding(10)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    // MARK: - Grades

    private var gradesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR GRADES")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            if gradeEntries.isEmpty {
                Text("Tap + to add a class and grade.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(gradeEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        gradeRow(entry)
                    }
                }
                .background(Theme.card)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
            }
        }
    }

    private func gradeRow(_ entry: GradeEntry) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(entry.courseName).font(.subheadline.weight(.medium)).foregroundStyle(Theme.primaryText)
                    if entry.isWeighted {
                        Text("W").font(.caption2.weight(.bold)).foregroundStyle(MindMapSection.school.accentColor)
                    }
                }
                Text(scalePoints(for: entry.gradeLabel) == nil ? "\(entry.gradeLabel) — no matching scale entry" : "\(entry.gradeLabel) · \(String(format: "%.1f", entry.credits)) credit\(entry.credits == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { editingGrade = entry }
    }
}

#Preview {
    NavigationStack {
        GPACalculatorView()
    }
    .modelContainer(for: [GradeScaleEntry.self, GradeEntry.self], inMemory: true)
}

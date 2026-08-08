//
//  GPACalculatorView.swift
//  Odysseus
//
//  Automatic, GradeScout-style: nothing to enter here. Each class's grade is
//  totaled live from the real points-earned/points-possible you log on its
//  assignments/quizzes/tests/projects, resolved to a letter and GPA points
//  through Rutgers Prep's scale (auto-seeded, still editable if it's wrong).
//  Add mock/what-if items per class to see a Projected GPA without touching
//  your real grades.
//

import SwiftUI
import SwiftData

struct GPACalculatorView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \GradeScaleEntry.sortIndex) private var scaleEntries: [GradeScaleEntry]
    @Query(sort: \SchoolClass.sortIndex) private var allClasses: [SchoolClass]

    @State private var newScaleLabel = ""
    @State private var newScalePoints = ""
    @State private var honorsBonus: Double = GPASettings.honorsBonus
    @State private var apBonus: Double = GPASettings.apBonus
    @State private var showingAddMock = false
    @State private var editingClass: SchoolClass?
    @State private var term: SchoolTerm = SchoolTermSettings.selected

    private var enrolledClasses: [SchoolClass] { allClasses.filter { $0.isEnrolled } }

    private struct ClassGrade {
        let schoolClass: SchoolClass
        let summary: SchoolClass.GradeSummary
        let scaleRow: GradeScaleEntry?
    }

    private func classGrade(_ schoolClass: SchoolClass, includeMock: Bool) -> ClassGrade {
        let summary = schoolClass.gradeSummary(includeMock: includeMock, term: term)
        let scaleRow = summary.percent.flatMap { GPASettings.scaleEntry(forPercent: $0, in: scaleEntries) }
        return ClassGrade(schoolClass: schoolClass, summary: summary, scaleRow: scaleRow)
    }

    private func bonus(for schoolClass: SchoolClass) -> Double {
        schoolClass.resolvedWeight.isAP ? apBonus : honorsBonus
    }

    private func gpa(includeMock: Bool) -> Double? {
        let rows = enrolledClasses.compactMap { schoolClass -> (points: Double, credits: Double)? in
            let grade = classGrade(schoolClass, includeMock: includeMock)
            guard let base = grade.scaleRow?.points else { return nil }
            let weight = schoolClass.resolvedWeight
            let bump = weight.isWeighted ? bonus(for: schoolClass) : 0
            return (base + bump, schoolClass.credits)
        }
        let totalCredits = rows.reduce(0) { $0 + $1.credits }
        guard totalCredits > 0 else { return nil }
        return rows.reduce(0) { $0 + $1.points * $1.credits } / totalCredits
    }

    private var hasAnyMock: Bool {
        enrolledClasses.contains { $0.directAssignments.contains { $0.isMock } }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                SemesterPicker(selection: $term)
                gpaSummary
                classesSection
                scaleSection
                bonusSection
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("GPA Calculator")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddMock = true } label: { Image(systemName: "plus") }
            }
        }
        .sheet(isPresented: $showingAddMock) {
            AddMockAssignmentView()
        }
        .sheet(item: $editingClass) { schoolClass in
            ClassGradeSettingsView(schoolClass: schoolClass)
        }
        .onAppear {
            if scaleEntries.isEmpty {
                GPASettings.seedRutgersPrepScale(into: modelContext, existing: scaleEntries)
                honorsBonus = GPASettings.honorsBonus
                apBonus = GPASettings.apBonus
            }
        }
        .onChange(of: term) { _, newValue in SchoolTermSettings.selected = newValue }
    }

    private var gpaSummary: some View {
        HStack(spacing: 12) {
            gpaStat("GPA", gpa(includeMock: false), emphasized: true)
            if hasAnyMock {
                gpaStat("PROJECTED", gpa(includeMock: true), emphasized: false)
            }
        }
    }

    private func gpaStat(_ label: String, _ value: Double?, emphasized: Bool) -> some View {
        VStack(spacing: 2) {
            Text(value.map { String(format: "%.2f", $0) } ?? "—")
                .font((emphasized ? Font.system(size: 34) : .title).weight(.heavy).monospacedDigit())
                .foregroundStyle(emphasized ? MindMapSection.school.accentColor : Theme.primaryText)
            Text(label)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .glassPanel(cornerRadius: 10, borderColor: emphasized ? MindMapSection.school.accentColor.opacity(0.7) : Theme.cardBorder)
    }

    // MARK: - Classes

    private var classesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR CLASSES")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            if enrolledClasses.isEmpty {
                Text("Add classes in School > Manage — grades total automatically once you log points on assignments/quizzes/tests/projects.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(enrolledClasses.enumerated()), id: \.element.id) { index, schoolClass in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        classRow(schoolClass)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func classRow(_ schoolClass: SchoolClass) -> some View {
        let grade = classGrade(schoolClass, includeMock: false)
        let weight = schoolClass.resolvedWeight
        return HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(schoolClass.name).font(.subheadline.weight(.medium)).foregroundStyle(Theme.primaryText)
                    if weight.isWeighted {
                        Text(weight.isAP ? "AP" : "HON")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .foregroundStyle(MindMapSection.school.accentColor)
                    }
                }
                if let percent = grade.summary.percent {
                    Text(grade.summary.isManual
                        ? "Manual grade"
                        : "\(String(format: "%.0f", grade.summary.pointsEarned))/\(String(format: "%.0f", grade.summary.pointsPossible)) pts · \(String(format: "%.1f", percent))%")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                } else {
                    Text("No graded work logged yet")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
            }
            Spacer()
            if let row = grade.scaleRow {
                VStack(spacing: 0) {
                    Text(row.label).font(.subheadline.weight(.bold)).foregroundStyle(Theme.primaryText)
                    Text(String(format: "%.2f", row.points + (weight.isWeighted ? bonus(for: schoolClass) : 0)))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(Theme.dimText)
                }
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { editingClass = schoolClass }
    }

    // MARK: - Scale

    private var scaleSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("GRADING SCALE")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button("Load Rutgers Prep") {
                    GPASettings.seedRutgersPrepScale(into: modelContext, existing: scaleEntries)
                    honorsBonus = GPASettings.honorsBonus
                    apBonus = GPASettings.apBonus
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(MindMapSection.school.accentColor)
            }

            HStack(spacing: 8) {
                TextField("Grade (e.g. A, B+)", text: $newScaleLabel)
                    .padding(8)
                    .glassPanel(cornerRadius: 8)
                    .onSubmit { if canAddScale { addScaleEntry() } }
                TextField("Points (e.g. 4.0)", text: $newScalePoints)
                    .platformKeyboardType(.decimalPad)
                    .padding(8)
                    .glassPanel(cornerRadius: 8)
                    .onSubmit { if canAddScale { addScaleEntry() } }
                Button(action: addScaleEntry) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canAddScale ? MindMapSection.school.accentColor : Theme.dimText)
                }
                .buttonStyle(.plain)
                .disabled(!canAddScale)
            }

            if scaleEntries.isEmpty {
                Text("Loads automatically from Rutgers Prep's chart — add or edit rows if your report card differs. Rows added here manually won't resolve percentages to a letter automatically (no percent band) — they're still usable for a manual override grade, though.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(scaleEntries.enumerated()), id: \.element.id) { index, entry in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        HStack {
                            Text(entry.label).font(.subheadline.weight(.medium)).foregroundStyle(Theme.primaryText)
                            Spacer()
                            if let min = entry.minPercent, let max = entry.maxPercent {
                                Text("\(String(format: "%.0f", min))–\(String(format: "%.0f", max))%")
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(Theme.dimText)
                            }
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
                .glassPanel(cornerRadius: 10)
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
            Text("HONORS/AP BUMP")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(spacing: 0) {
                bonusRow("Honors", Binding(
                    get: { honorsBonus },
                    set: { honorsBonus = $0; GPASettings.honorsBonus = $0 }
                ))
                Divider().overlay(Theme.cardBorder)
                bonusRow("AP", Binding(
                    get: { apBonus },
                    set: { apBonus = $0; GPASettings.apBonus = $0 }
                ))
            }
            .glassPanel(cornerRadius: 10)
        }
    }

    private func bonusRow(_ label: String, _ binding: Binding<Double>) -> some View {
        HStack {
            Text("Added to weighted GPA for \(label) courses")
                .font(.caption)
                .foregroundStyle(Theme.dimText)
            Spacer()
            TextField("0.333", value: binding, format: .number)
                .platformKeyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(width: 60)
        }
        .padding(10)
    }
}

// MARK: - Class settings (credits, weight override, manual grade, mock items)

private struct ClassGradeSettingsView: View {
    @Bindable var schoolClass: SchoolClass

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var creditsText = ""
    @State private var manualPercentText = ""

    private var mockAssignments: [Assignment] { schoolClass.directAssignments.filter(\.isMock) }
    private var realAssignments: [Assignment] { schoolClass.directAssignments.filter { !$0.isMock && $0.isGraded } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Weight") {
                    Picker("Honors/AP", selection: $schoolClass.weightOverride) {
                        ForEach(GradeWeightOverride.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    TextField("Credits", text: $creditsText)
                        .platformKeyboardType(.decimalPad)
                        .onChange(of: creditsText) { _, newValue in
                            if let value = Double(newValue) { schoolClass.credits = value }
                        }
                }
                Section("Manual override") {
                    TextField("Set a grade % directly (optional)", text: $manualPercentText)
                        .platformKeyboardType(.decimalPad)
                        .onChange(of: manualPercentText) { _, newValue in
                            schoolClass.manualPercentOverride = Double(newValue)
                        }
                    Text(realAssignments.isEmpty
                        ? "Used until you've logged enough graded work to compute a real grade."
                        : "Only used as a fallback — real logged points take priority once there's any.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
                if !mockAssignments.isEmpty {
                    Section("What-if items") {
                        ForEach(mockAssignments) { item in
                            HStack {
                                Text(item.title)
                                Spacer()
                                Text("\(item.pointsEarned?.formatted() ?? "—")/\(item.pointsPossible?.formatted() ?? "—")")
                                    .foregroundStyle(Theme.dimText)
                            }
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(mockAssignments[index]) }
                        }
                    }
                }
            }
            .navigationTitle(schoolClass.name)
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                creditsText = schoolClass.credits.formatted()
                manualPercentText = schoolClass.manualPercentOverride.map { $0.formatted() } ?? ""
            }
        }
    }
}

// MARK: - Mock (what-if) assignment

private struct AddMockAssignmentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \SchoolClass.sortIndex) private var allClasses: [SchoolClass]

    @State private var selectedClassID: String?
    @State private var title = ""
    @State private var type: AssignmentType = .assignment
    @State private var pointsEarned = ""
    @State private var pointsPossible = ""

    private var enrolledClasses: [SchoolClass] { allClasses.filter { $0.isEnrolled } }

    var body: some View {
        NavigationStack {
            Form {
                Section("What if…") {
                    Picker("Class", selection: $selectedClassID) {
                        Text("Select").tag(String?.none)
                        ForEach(enrolledClasses) { schoolClass in
                            Text(schoolClass.name).tag(Optional(schoolClass.id))
                        }
                    }
                    TextField("Title (e.g. \"Unit 4 Test\")", text: $title)
                    Picker("Type", selection: $type) {
                        ForEach(AssignmentType.allCases) { type in
                            Text(type.displayName).tag(type)
                        }
                    }
                    HStack {
                        TextField("Points earned", text: $pointsEarned)
                            .platformKeyboardType(.decimalPad)
                        Text("/").foregroundStyle(Theme.dimText)
                        TextField("Points possible", text: $pointsPossible)
                            .platformKeyboardType(.decimalPad)
                    }
                }
                Section {
                    Text("Counts only toward the Projected GPA above — never your real grade. Delete it anytime from that class's settings.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
            }
            .navigationTitle("What-If Item")
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
        }
    }

    private var canSave: Bool {
        selectedClassID != nil && !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && Double(pointsEarned) != nil && Double(pointsPossible) != nil
    }

    private func save() {
        guard let classID = selectedClassID, let schoolClass = enrolledClasses.first(where: { $0.id == classID }),
              let earned = Double(pointsEarned), let possible = Double(pointsPossible) else { return }
        let mock = Assignment(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            schoolClass: schoolClass,
            type: type,
            pointsEarned: earned,
            pointsPossible: possible,
            isMock: true
        )
        modelContext.insert(mock)
        dismiss()
    }
}

#Preview {
    NavigationStack {
        GPACalculatorView()
    }
    .modelContainer(for: [GradeScaleEntry.self, SchoolClass.self, Topic.self, Assignment.self], inMemory: true)
}

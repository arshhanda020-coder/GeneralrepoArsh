//
//  GPACalculatorView.swift
//  Odysseus
//
//  Fully automatic — pulls straight from the Classes list, so there's
//  nothing to set up. Each class's weighting tier (Regular/Honors/AP) is
//  read off its name the way Rutgers Prep itself labels courses, and the
//  Honors/AP GPA bump follows Rutgers Prep's official policy (see
//  `RutgersPrepGPA`). The only thing left to tap in is your current letter
//  grade per class, since that lives in Rutgers Prep's own gradebook.
//

import SwiftUI
import SwiftData

struct GPACalculatorView: View {
    @Query(sort: \SchoolClass.sortIndex) private var allClasses: [SchoolClass]

    private var enrolledClasses: [SchoolClass] { allClasses.filter(\.isEnrolled) }
    private var gradedClasses: [SchoolClass] { enrolledClasses.filter { $0.gradeLabel != nil } }

    private func gpa(weighted: Bool) -> Double? {
        let scored = gradedClasses.compactMap { schoolClass -> Double? in
            guard let label = schoolClass.gradeLabel else { return nil }
            return RutgersPrepGPA.points(for: label, level: schoolClass.courseLevel, weighted: weighted)
        }
        guard !scored.isEmpty else { return nil }
        return scored.reduce(0, +) / Double(scored.count)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                gpaSummary
                classesSection
                policyNote
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("GPA Calculator")
        .inlineNavigationTitle()
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
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity)
        .padding(12)
        .glassPanel(cornerRadius: 10)
    }

    // MARK: - Classes

    private var classesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR CLASSES")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            if enrolledClasses.isEmpty {
                Text("Add your classes in the Classes section above — your GPA fills in automatically once they're there.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(enrolledClasses.enumerated()), id: \.element.id) { index, schoolClass in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        classGradeRow(schoolClass)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func classGradeRow(_ schoolClass: SchoolClass) -> some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text(schoolClass.name)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                levelMenu(schoolClass)
            }
            Spacer()
            gradeMenu(schoolClass)
        }
        .padding(10)
    }

    private func levelMenu(_ schoolClass: SchoolClass) -> some View {
        Menu {
            ForEach(CourseLevel.allCases) { level in
                Button {
                    schoolClass.courseLevelOverrideRaw = level.rawValue
                } label: {
                    if schoolClass.courseLevel == level { Label(level.displayName, systemImage: "checkmark") }
                    else { Text(level.displayName) }
                }
            }
            if schoolClass.courseLevelOverrideRaw != nil {
                Divider()
                Button("Reset to auto-detected") { schoolClass.courseLevelOverrideRaw = nil }
            }
        } label: {
            HStack(spacing: 3) {
                Text(schoolClass.courseLevel.displayName.uppercased())
                if schoolClass.courseLevelOverrideRaw == nil {
                    Image(systemName: "sparkles").font(.system(size: 8))
                }
            }
            .font(.system(.caption2, design: .monospaced).weight(.bold))
            .foregroundStyle(schoolClass.courseLevel == .regular ? Theme.dimText : MindMapSection.school.accentColor)
        }
        .buttonStyle(.plain)
    }

    private func gradeMenu(_ schoolClass: SchoolClass) -> some View {
        Menu {
            ForEach(RutgersPrepGPA.labels, id: \.self) { label in
                Button {
                    schoolClass.gradeLabel = label
                } label: {
                    Text(RutgersPrepGPA.percentRange(for: label).map { "\(label) (\($0)%)" } ?? label)
                }
            }
            if schoolClass.gradeLabel != nil {
                Divider()
                Button("Clear", role: .destructive) { schoolClass.gradeLabel = nil }
            }
        } label: {
            Text(schoolClass.gradeLabel ?? "Set grade")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(schoolClass.gradeLabel == nil ? Theme.dimText : Theme.primaryText)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .glassPanel(cornerRadius: 8)
        }
        .buttonStyle(.plain)
    }

    private var policyNote: some View {
        Text("Grading follows Rutgers Prep's official table — Honors +0.333, AP/P-AP +0.667 GPA points per grade — applied automatically based on each class's title. Override a class's level above if it's ever detected wrong.")
            .font(.caption2)
            .foregroundStyle(Theme.dimText)
    }
}

#Preview {
    NavigationStack {
        GPACalculatorView()
    }
    .modelContainer(for: [SchoolClass.self], inMemory: true)
}

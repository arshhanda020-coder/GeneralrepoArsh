//
//  ExamStudyPlanView.swift
//  Odysseus
//
//  One study-plan generator for any exam category (ACT, AP Exams, March
//  Exams): feed it material (text/photos) and it writes a personalized plan
//  — for ACT/AP that means goal/target-driven, recommending resources and a
//  session schedule; for March Exams it's built from what's actually logged
//  across your classes/topics — plus a dated pacing checklist spread across
//  the whole runway to the exam (not just a cram week) so nothing goes
//  stale, practice-test shortcuts, and free-form study session logging.
//

import SwiftUI
import SwiftData
import PhotosUI

struct ExamStudyPlanView: View {
    @Bindable var exam: Exam

    @Environment(\.modelContext) private var modelContext
    @Query private var allPlans: [ACTPrepPlan]
    @Query private var allSessions: [StudySession]
    @Query private var allMaterial: [StudyMaterial]
    @Query(sort: \PacingItem.scheduledDate) private var allPacingItems: [PacingItem]
    @Query(sort: \SchoolClass.sortIndex) private var allClasses: [SchoolClass]

    @State private var isGeneratingPlan = false
    @State private var errorMessage: String?
    @State private var showingLogSession = false
    @State private var showingAddMaterial = false

    private var plan: ACTPrepPlan? {
        allPlans.filter { $0.exam?.id == exam.id }.sorted { $0.generatedAt > $1.generatedAt }.first
    }
    private var sessions: [StudySession] {
        allSessions.filter { $0.exam?.id == exam.id }.sorted { $0.date > $1.date }
    }
    private var material: [StudyMaterial] {
        allMaterial.filter { $0.exam?.id == exam.id }.sorted { $0.addedAt > $1.addedAt }
    }
    private var pacingItems: [PacingItem] {
        allPacingItems.filter { $0.exam?.id == exam.id }
    }
    private var enrolledClasses: [SchoolClass] { allClasses.filter { $0.isEnrolled } }
    private var isMarchExam: Bool { exam.category == .marchExams }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                planSection
                if !pacingItems.isEmpty { pacingSection }
                materialSection
                practiceSection
                sessionsSection
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Study Plan")
        .inlineNavigationTitle()
        .sheet(isPresented: $showingLogSession) {
            LogStudySessionSheet(exam: exam)
        }
        .sheet(isPresented: $showingAddMaterial) {
            AddStudyMaterialView(exam: exam)
        }
    }

    // MARK: - Plan

    private var planSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("STUDY PLAN")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                if let plan {
                    Text(plan.planText)
                        .font(.caption)
                        .foregroundStyle(Theme.primaryText)
                    Text("Generated \(plan.generatedAt.formatted(.dateTime.month(.abbreviated).day()))")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                } else {
                    Text(isMarchExam
                        ? "No plan yet. Generate one from \(exam.name)'s date and everything you've logged across your classes."
                        : "No plan yet. Set a target score on this exam (edit it from School), add any resources under Material, then generate a personalized plan — recommended resources, a study schedule, and a pacing checklist.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }

                Button {
                    generatePlan()
                } label: {
                    Label(isGeneratingPlan ? "Generating…" : (plan == nil ? "Generate Plan" : "Regenerate Plan"), systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.school.accentColor)
                .disabled(isGeneratingPlan)

                if let errorMessage {
                    Text(errorMessage).font(.caption).foregroundStyle(Theme.negative)
                }
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
        }
    }

    // MARK: - Pacing checklist

    private var pacingSection: some View {
        let sorted = pacingItems.sorted { $0.scheduledDate < $1.scheduledDate }
        let doneCount = sorted.filter(\.isDone).count
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("PACING")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Text("\(doneCount)/\(sorted.count) done")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
            }
            VStack(spacing: 0) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, item in
                    if index > 0 { Divider().overlay(Theme.cardBorder) }
                    pacingRow(item)
                }
            }
            .glassPanel(cornerRadius: 10)
        }
    }

    private func pacingRow(_ item: PacingItem) -> some View {
        let isOverdue = !item.isDone && item.scheduledDate < Calendar.current.startOfDay(for: .now)
        return HStack(spacing: 10) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) { item.isDone.toggle() }
            } label: {
                Image(systemName: item.isDone ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(item.isDone ? MindMapSection.school.accentColor : Theme.dimText)
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                HStack(spacing: 4) {
                    Text(item.title)
                        .font(.subheadline)
                        .foregroundStyle(item.isDone ? Theme.dimText : Theme.primaryText)
                        .strikethrough(item.isDone)
                    Text(item.kind.displayName.uppercased())
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(MindMapSection.school.accentColor)
                }
                if let detail = item.detail, !detail.isEmpty {
                    Text(detail).font(.caption2).foregroundStyle(Theme.dimText)
                }
            }
            Spacer()
            Text(item.scheduledDate.formatted(.dateTime.month(.abbreviated).day()))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(isOverdue ? Theme.negative : Theme.dimText)
        }
        .padding(10)
    }

    // MARK: - Material

    private var materialSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("MATERIAL")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button {
                    showingAddMaterial = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MindMapSection.school.accentColor)
                }
                .buttonStyle(.plain)
            }

            if material.isEmpty {
                Text("Give the AI anything worth building the plan around — pasted notes, a photo of a review sheet, a link to a resource you're using.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(material.enumerated()), id: \.element.id) { index, item in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        HStack(spacing: 10) {
                            if let photoData = item.photoData, let uiImage = PlatformImage(data: photoData) {
                                Image(platformImage: uiImage)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 36, height: 36)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                            }
                            Text(item.text?.isEmpty == false ? item.text! : "Photo")
                                .font(.caption)
                                .foregroundStyle(Theme.primaryText)
                                .lineLimit(2)
                            Spacer()
                            Button {
                                modelContext.delete(item)
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

    // MARK: - Practice tests

    private var practiceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PRACTICE TESTS")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            if isMarchExam && !enrolledClasses.isEmpty {
                VStack(spacing: 0) {
                    ForEach(Array(enrolledClasses.enumerated()), id: \.element.id) { index, schoolClass in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        practiceRow(schoolClass.name)
                    }
                }
                .glassPanel(cornerRadius: 10)
            } else {
                practiceRow(exam.name)
                    .glassPanel(cornerRadius: 10)
            }
        }
    }

    private func practiceRow(_ subject: String) -> some View {
        NavigationLink(destination: TestMeView(presetSubject: subject)) {
            HStack {
                Text(subject)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.primaryText)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sessions

    private var sessionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("STUDY SESSIONS")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                Button {
                    showingLogSession = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(MindMapSection.school.accentColor)
                }
                .buttonStyle(.plain)
            }

            if sessions.isEmpty {
                Text("Nothing logged yet — log every session (a resource you used, concept review, self-testing) so the plan can adapt to what you've actually put in.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(sessions.prefix(30).enumerated()), id: \.element.id) { index, session in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        HStack {
                            VStack(alignment: .leading, spacing: 1) {
                                Text(session.subjectArea ?? "General")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.primaryText)
                                if let note = session.note, !note.isEmpty {
                                    Text(note).font(.caption2).foregroundStyle(Theme.dimText)
                                }
                            }
                            Spacer()
                            if let minutes = session.durationMinutes {
                                Text("\(minutes)m").font(.caption2.monospacedDigit()).foregroundStyle(Theme.dimText)
                            }
                            Text(session.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(Theme.dimText)
                        }
                        .padding(10)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
    }

    // MARK: - AI

    /// One line per topic: class > topic — pending assignment titles, done
    /// count. March Exams only. Summer Work is deliberately excluded — it's
    /// separate from the regular curriculum this is testing on.
    private var loggedMaterial: [String] {
        enrolledClasses.flatMap { schoolClass -> [String] in
            schoolClass.topics.filter { !$0.isSummerWork }.sorted { $0.sortIndex < $1.sortIndex }.map { topic in
                let pending = topic.assignments.filter { !$0.isDone }.map(\.title)
                let doneCount = topic.assignments.filter(\.isDone).count
                var line = "\(schoolClass.name) > \(topic.name)"
                if !pending.isEmpty { line += " — pending: \(pending.joined(separator: ", "))" }
                if doneCount > 0 { line += " (\(doneCount) completed)" }
                return line
            }
        }
    }

    private func generatePlan() {
        isGeneratingPlan = true
        errorMessage = nil

        Task {
            do {
                let materialContext = await describedMaterial()
                let prompt = buildPrompt(materialContext: materialContext)
                let text = try await AISettings.currentService.draft(prompt: prompt)
                let (overview, items) = Self.parsePlanResponse(text, examId: exam.id)

                let newPlan = ACTPrepPlan(exam: exam, planText: overview)
                modelContext.insert(newPlan)
                for draft in items {
                    guard let scheduledDate = Calendar.current.date(byAdding: .day, value: draft.daysFromNow, to: Calendar.current.startOfDay(for: .now)) else { continue }
                    modelContext.insert(PacingItem(exam: exam, title: draft.title, detail: draft.detail, kind: draft.kind, scheduledDate: scheduledDate))
                }
            } catch {
                errorMessage = error.localizedDescription
            }
            isGeneratingPlan = false
        }
    }

    /// Vision-describes any attached photos (capped, so this stays fast) and folds them in with typed material text.
    private func describedMaterial() async -> String {
        var lines: [String] = material.compactMap { item -> String? in
            guard let text = item.text, !text.isEmpty else { return nil }
            return "- \(text)"
        }
        for item in material.compactMap({ $0.photoData != nil ? $0 : nil }).prefix(5) {
            guard let description = try? await AISettings.currentService.askAboutImage(
                prompt: "Briefly describe what's shown in this photo (a study resource, notes, a review sheet, etc.) in 1-2 sentences, plain text.",
                imageData: item.photoData,
                systemPrompt: "You are summarizing a photo of study material for a student's exam prep plan."
            ) else { continue }
            lines.append("- Photo: \(description)")
        }
        return lines.joined(separator: "\n")
    }

    private func buildPrompt(materialContext: String) -> String {
        let daysUntil = exam.daysUntil
        let sessionHistory = sessions.prefix(20).map { "\($0.date.formatted(.dateTime.month(.abbreviated).day())): \($0.subjectArea ?? "General")\($0.note.map { " — \($0)" } ?? "")\($0.durationMinutes.map { " (\($0)m)" } ?? "")" }.joined(separator: "\n")

        let scopeContext: String
        if isMarchExam {
            scopeContext = """
            Material logged across the student's classes and topics (this is what's actually been covered — use it, don't invent generic subjects):
            \(loggedMaterial.joined(separator: "\n"))
            """
        } else {
            scopeContext = """
            This is a \(exam.category.displayName) exam. Recommend specific, real study resources/textbooks/apps where relevant (general knowledge is fine if the student hasn't named any).
            """
        }

        return """
        Write a personalized study plan for an upcoming exam, in two parts.

        Exam: \(exam.name) (\(exam.category.displayName))
        Date: \(exam.examDate.formatted(.dateTime.month(.wide).day().year())) (\(daysUntil) days away)
        Target score / goal: \(exam.targetScore ?? "not specified")

        \(scopeContext)

        Material/resources the student has given you:
        \(materialContext.isEmpty ? "none logged yet" : materialContext)

        Recent study sessions logged:
        \(sessionHistory.isEmpty ? "none logged yet" : sessionHistory)

        PART 1 — OVERVIEW: A realistic plan given the time remaining — what to focus on and why, recommended resources if this is ACT/AP, weighted toward whatever seems weakest or most pending. Specific and actionable, referencing what's actually been given above. Plain text, no markdown headers. Prefix this part with the line "OVERVIEW:" then the text.

        PART 2 — PACING: A dated checklist of 8-16 items spread evenly across the \(daysUntil)-day runway (not all crammed near the end) so material stays fresh — a realistic mix of reviews, practice assignments/homework, and practice tests. After the overview, write the line "===PACING===" then one block per item in EXACTLY this format, separated by a line containing only ---:
        DATE: <integer days from today>
        KIND: REVIEW or ASSIGNMENT or HOMEWORK or TEST
        TITLE: <short title>
        DETAIL: <one sentence>
        """
    }

    private struct PacingDraft {
        let daysFromNow: Int
        let kind: PacingItemKind
        let title: String
        let detail: String?
    }

    nonisolated private static func parsePlanResponse(_ text: String, examId: String) -> (overview: String, items: [PacingDraft]) {
        let parts = text.components(separatedBy: "===PACING===")
        var overview = parts.first ?? text
        if let range = overview.range(of: "OVERVIEW:", options: .caseInsensitive) {
            overview = String(overview[range.upperBound...])
        }
        overview = overview.trimmingCharacters(in: .whitespacesAndNewlines)

        var items: [PacingDraft] = []
        if parts.count > 1 {
            let blocks = parts[1].components(separatedBy: "---")
            for block in blocks {
                let lines = block.split(separator: "\n", omittingEmptySubsequences: true).map { $0.trimmingCharacters(in: .whitespaces) }
                guard let dateLine = lines.first(where: { $0.uppercased().hasPrefix("DATE:") }),
                      let days = Int(dateLine.dropFirst("DATE:".count).trimmingCharacters(in: .whitespaces)),
                      let titleLine = lines.first(where: { $0.uppercased().hasPrefix("TITLE:") }) else { continue }
                let title = titleLine.dropFirst("TITLE:".count).trimmingCharacters(in: .whitespaces)
                guard !title.isEmpty else { continue }
                let kindLine = lines.first(where: { $0.uppercased().hasPrefix("KIND:") })?.dropFirst("KIND:".count).trimmingCharacters(in: .whitespaces).uppercased() ?? ""
                let kind: PacingItemKind = kindLine.contains("TEST") ? .test : kindLine.contains("HOMEWORK") ? .homework : kindLine.contains("ASSIGNMENT") ? .assignment : .review
                let detail = lines.first(where: { $0.uppercased().hasPrefix("DETAIL:") })?.dropFirst("DETAIL:".count).trimmingCharacters(in: .whitespaces)
                items.append(PacingDraft(daysFromNow: max(0, days), kind: kind, title: title, detail: detail?.isEmpty == true ? nil : detail))
            }
        }
        return (overview.isEmpty ? text : overview, items)
    }
}

private struct AddStudyMaterialView: View {
    let exam: Exam

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var photoItem: PhotosPickerItem?
    @State private var photoData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Text") {
                    TextField("Paste notes, a resource link, anything useful", text: $text, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Photo") {
                    if let photoData, let uiImage = PlatformImage(data: photoData) {
                        Image(platformImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 160)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        Label(photoData == nil ? "Add photo" : "Replace photo", systemImage: "camera")
                    }
                }
            }
            .navigationTitle("Add Material")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && photoData == nil)
                }
            }
            .onChange(of: photoItem) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        photoData = PlatformImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                    }
                }
            }
        }
    }

    private func save() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(StudyMaterial(exam: exam, text: trimmed.isEmpty ? nil : trimmed, photoData: photoData))
        dismiss()
    }
}

#Preview {
    NavigationStack {
        ExamStudyPlanView(exam: Exam(name: "ACT June", examDate: .now.addingTimeInterval(60 * 60 * 24 * 60), category: .act))
    }
    .modelContainer(for: [Exam.self, ACTPrepPlan.self, StudySession.self, StudyMaterial.self, PacingItem.self, SchoolClass.self, Topic.self, Assignment.self], inMemory: true)
}

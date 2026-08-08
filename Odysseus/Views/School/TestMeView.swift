//
//  TestMeView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct TestMeView: View {
    /// Set when navigated to from a specific Topic — locks the subject, and
    /// feeds every assignment + note logged under that topic into quiz
    /// generation as material, instead of just the topic name.
    var presetTopic: Topic?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \QuizSession.createdAt, order: .reverse) private var sessions: [QuizSession]
    @Query private var topicNotes: [Note]

    @State private var subject = ""
    @State private var difficulty: Difficulty = .normal
    @State private var isGenerating = false
    @State private var errorMessage: String?
    @State private var activeSession: QuizSession?

    enum Difficulty: String, CaseIterable, Identifiable {
        case easier, normal, harder
        var id: String { rawValue }
        var label: String {
            switch self {
            case .easier: return "Easier"
            case .normal: return "Normal"
            case .harder: return "Harder"
            }
        }
        /// Nil for "normal" — omitting the field entirely reads as "use your
        /// own judgment" to the model, same as not asking for anything special.
        var prompt: String? {
            switch self {
            case .easier: return "noticeably easier / more basic than typical for this level"
            case .normal: return nil
            case .harder: return "noticeably harder / more advanced than typical for this level"
            }
        }
    }

    init(presetTopic: Topic? = nil) {
        self.presetTopic = presetTopic
        let typeRaw = NoteContext.topic(presetTopic?.id ?? "").typeRaw
        let recordID = presetTopic?.id
        _topicNotes = Query(filter: #Predicate<Note> { $0.contextTypeRaw == typeRaw && $0.contextID == recordID })
    }

    private var submittedSessions: [QuizSession] { sessions.filter { $0.isSubmitted } }

    /// Everything logged for the topic — assignments (with notes/done state)
    /// and freeform notes — as one text block handed to quiz generation so
    /// it tests the topic's actual material instead of generic knowledge.
    private var topicMaterial: String? {
        guard let presetTopic else { return nil }
        var lines: [String] = []
        if !presetTopic.assignments.isEmpty {
            lines.append("ASSIGNMENTS:")
            for assignment in presetTopic.assignments.sorted(by: { $0.createdAt < $1.createdAt }) {
                var line = "- \(assignment.title) (\(assignment.isDone ? "done" : "not done"))"
                if let notes = assignment.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    line += ": \(notes)"
                }
                lines.append(line)
            }
        }
        if !topicNotes.isEmpty {
            lines.append("\nNOTES:")
            for note in topicNotes {
                var line = "- \(note.title)"
                if !note.content.isEmpty { line += ": \(note.content)" }
                lines.append(line)
            }
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    private var masterySummary: [(subject: String, correct: Int, total: Int)] {
        let grouped = Dictionary(grouping: submittedSessions, by: { $0.subject })
        return grouped.map { subject, items in
            (subject, items.reduce(0) { $0 + $1.score }, items.reduce(0) { $0 + $1.totalQuestions })
        }.sorted { $0.subject < $1.subject }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("SUBJECT")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(0.5)
                        .foregroundStyle(Theme.dimText)
                    if presetTopic != nil {
                        Text(subject)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.primaryText)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .glassPanel(cornerRadius: 8)
                        if let topicMaterial, !topicMaterial.isEmpty {
                            Text("Pulls from every assignment and note logged under this topic.")
                                .font(.caption2)
                                .foregroundStyle(Theme.dimText)
                        }
                    } else {
                        TextField("e.g. Stoichiometry, WWII causes, Derivatives", text: $subject)
                            .padding(10)
                            .glassPanel(cornerRadius: 8)
                            .onSubmit {
                                guard !isGenerating, !subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                                generateQuiz()
                            }
                    }

                    Picker("Difficulty", selection: $difficulty) {
                        ForEach(Difficulty.allCases) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        generateQuiz()
                    } label: {
                        Label(isGenerating ? "Generating…" : "Test me", systemImage: "questionmark.circle.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(MindMapSection.school.accentColor)
                    .disabled(isGenerating || subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.negative)
                }

                if !masterySummary.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MASTERY")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Theme.dimText)
                        ForEach(masterySummary, id: \.subject) { entry in
                            masteryRow(entry)
                        }
                    }
                }

                if !submittedSessions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("PAST TESTS")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .tracking(0.5)
                            .foregroundStyle(Theme.dimText)
                        VStack(spacing: 0) {
                            ForEach(Array(submittedSessions.enumerated()), id: \.element.id) { index, session in
                                if index > 0 {
                                    Divider().overlay(Theme.cardBorder)
                                }
                                pastTestRow(session)
                            }
                        }
                        .glassPanel(cornerRadius: 10)
                    }
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Test Me")
        .inlineNavigationTitle()
        .onAppear {
            if let presetTopic, subject.isEmpty {
                subject = presetTopic.name
            }
        }
        .platformFullScreenCover(item: $activeSession) { session in
            QuizSessionView(session: session)
        }
    }

    private func masteryRow(_ entry: (subject: String, correct: Int, total: Int)) -> some View {
        HStack {
            Text(entry.subject)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(Theme.primaryText)
            Spacer()
            Text("\(entry.correct)/\(entry.total)")
                .foregroundStyle(MindMapSection.school.accentColor)
        }
        .font(.caption.monospacedDigit())
        .padding(10)
        .glassPanel(cornerRadius: 8)
    }

    private func pastTestRow(_ session: QuizSession) -> some View {
        Button {
            activeSession = session
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(session.subject)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.primaryText)
                    Text(session.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                Text("\(session.score)/\(session.totalQuestions)")
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                    .foregroundStyle(MindMapSection.school.accentColor)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func generateQuiz() {
        isGenerating = true
        errorMessage = nil
        let topic = subject.trimmingCharacters(in: .whitespacesAndNewlines)

        Task {
            do {
                let drafts = try await AISettings.currentService.generateQuiz(
                    subject: topic,
                    count: 6,
                    material: topicMaterial,
                    difficulty: difficulty.prompt
                )
                guard !drafts.isEmpty else {
                    errorMessage = "Couldn't generate questions — try again."
                    isGenerating = false
                    return
                }
                let session = QuizSession(subject: topic, totalQuestions: drafts.count)
                modelContext.insert(session)
                for (index, draft) in drafts.enumerated() {
                    modelContext.insert(QuizQuestion(
                        sortIndex: index,
                        text: draft.text,
                        type: draft.type,
                        choices: draft.choices,
                        correctAnswer: draft.correctAnswer,
                        session: session
                    ))
                }
                activeSession = session
            } catch {
                errorMessage = error.localizedDescription
            }
            isGenerating = false
        }
    }
}

#Preview {
    NavigationStack {
        TestMeView()
    }
    .modelContainer(for: [QuizSession.self, QuizQuestion.self, Note.self, Topic.self, Assignment.self], inMemory: true)
}

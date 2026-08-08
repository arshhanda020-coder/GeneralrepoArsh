//
//  TopicAssistantController.swift
//  Odysseus
//
//  Per-topic Study Assistant — the same AI provider/model Copilot uses
//  (whichever the user has picked in Settings, Claude or ChatGPT), but
//  scoped to exactly one School topic instead of Copilot's whole app
//  surface. Every turn's system prompt is rebuilt fresh from that topic's
//  logged assignments and freeform notes, so the assistant always answers
//  from (and can quiz on) everything actually in the topic — and it has
//  exactly two tools instead of Copilot's 25+: regenerate a practice quiz
//  at a given difficulty, and log a real test/quiz score the student
//  reports back.
//

import Foundation
import Combine
import SwiftData

@MainActor
final class TopicAssistantController: ObservableObject {
    @Published var isSending = false
    @Published var statusMessage: String?
    /// Set by the generate_quiz tool once a fresh QuizSession is ready to
    /// take — the view presents it full-screen as soon as this is non-nil.
    @Published var pendingQuizSession: QuizSession?

    /// Finds (or creates) the one persistent thread for this topic. Unlike
    /// Copilot's "New Chat" flow, there's deliberately no way to start a
    /// second thread per topic — one running conversation per topic keeps
    /// "make it harder than last time" and "log that score" contextual.
    func resolveSession(for topic: Topic, context: ModelContext) -> ChatSession {
        let topicID = topic.id
        if let existing = try? context.fetch(FetchDescriptor<ChatSession>(
            predicate: #Predicate<ChatSession> { $0.topicID == topicID }
        )).first {
            return existing
        }
        let session = ChatSession(title: "Study: \(topic.name)", topicID: topicID)
        context.insert(session)
        return session
    }

    func sendMessage(_ text: String, topic: Topic, session: ChatSession, context: ModelContext) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard AISettings.hasActiveKey else {
            statusMessage = "Add your \(AISettings.provider.displayName) API key in Copilot settings (key icon)."
            return
        }

        isSending = true
        statusMessage = nil

        let userMessage = ChatMessage(role: "user", content: trimmed, session: session)
        context.insert(userMessage)
        session.lastActivityAt = .now

        let sessionID = session.id
        let history = (try? context.fetch(
            FetchDescriptor<ChatMessage>(
                predicate: #Predicate { $0.session?.id == sessionID },
                sortBy: [SortDescriptor(\.createdAt)]
            )
        )) ?? []

        // Inserted empty and filled in live as tokens stream — matches
        // Copilot's word-by-word reveal instead of one long silent wait.
        let assistantMessage = ChatMessage(role: "assistant", content: "", session: session)
        context.insert(assistantMessage)

        do {
            let reply = try await AISettings.currentService.send(
                history: history,
                onTextDelta: { delta in assistantMessage.content += delta },
                systemPrompt: systemPrompt(for: topic, context: context),
                tools: AISettings.provider == .claude ? Self.anthropicTools : Self.openAITools
            ) { [weak self] name, input in
                guard let self else { return "Unknown tool." }
                return await self.executeTool(name: name, input: input, topic: topic, context: context)
            }
            assistantMessage.content = reply
        } catch {
            context.delete(assistantMessage)
            statusMessage = error.localizedDescription
        }
        isSending = false
    }

    // MARK: - System prompt (rebuilt every turn so edits are always current)

    private func systemPrompt(for topic: Topic, context: ModelContext) -> String {
        """
        You are a study assistant for exactly one School topic — "\(topic.name)"\(topic.schoolClass.map { " in \($0.name)" } ?? "") — \
        stay scoped to it. Answer questions and help the student understand this topic using their own logged material below \
        (assignments and notes) plus your general knowledge of the subject to fill gaps or explain further. You can also: \
        generate_quiz — put together (or regenerate) a practice quiz on this topic, built from the material below, and open \
        it for them to take right away. If they ask to be tested/quizzed, or to make the last one harder or easier, call this \
        — pass their difficulty ask straight through in the `difficulty` field (e.g. "harder than last time", "easier"). \
        log_quiz_score — if they tell you about a real test/quiz score from outside the app (e.g. "I got a 90 on my chem \
        test"), log it so it counts toward this topic's mastery stats and past-tests history. Be concise and encouraging, \
        like a good tutor working one-on-one — not a chipper corporate assistant, no exclamation points, no emoji.

        \(topicMaterialText(for: topic, context: context))
        """
    }

    /// Everything logged for the topic — every assignment (with its notes
    /// and done state) and every freeform Note attached to it — as one
    /// plain-text block. Shared by the system prompt (so the assistant can
    /// discuss it) and generate_quiz (so questions are drawn from it).
    private func topicMaterialText(for topic: Topic, context: ModelContext) -> String {
        var lines: [String] = []

        if topic.assignments.isEmpty {
            lines.append("ASSIGNMENTS: none logged yet.")
        } else {
            lines.append("ASSIGNMENTS:")
            for assignment in topic.assignments.sorted(by: { $0.createdAt < $1.createdAt }) {
                var line = "- \(assignment.title) (\(assignment.isDone ? "done" : "not done"))"
                if let notes = assignment.notes, !notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    line += ": \(notes)"
                }
                lines.append(line)
            }
        }

        let notes = topicNotes(for: topic, context: context)
        if notes.isEmpty {
            lines.append("\nNOTES: none logged yet.")
        } else {
            lines.append("\nNOTES:")
            for note in notes {
                var line = "- \(note.title)"
                if !note.content.isEmpty { line += ": \(note.content)" }
                lines.append(line)
            }
        }

        return lines.joined(separator: "\n")
    }

    private func topicNotes(for topic: Topic, context: ModelContext) -> [Note] {
        let typeRaw = NoteContext.topic(topic.id).typeRaw
        let recordID = topic.id
        return (try? context.fetch(FetchDescriptor<Note>(
            predicate: #Predicate<Note> { $0.contextTypeRaw == typeRaw && $0.contextID == recordID },
            sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
        ))) ?? []
    }

    // MARK: - Tool execution

    private func executeTool(name: String, input: [String: Any], topic: Topic, context: ModelContext) async -> String {
        switch name {
        case "generate_quiz":
            return await generateQuiz(
                count: input["count"] as? Int,
                difficulty: input["difficulty"] as? String,
                topic: topic,
                context: context
            )
        case "log_quiz_score":
            return logQuizScore(
                score: input["score"] as? Int,
                total: input["total"] as? Int,
                note: input["note"] as? String,
                topic: topic,
                context: context
            )
        default:
            return "Unknown tool."
        }
    }

    private func generateQuiz(count: Int?, difficulty: String?, topic: Topic, context: ModelContext) async -> String {
        let clamped = max(3, min(count ?? 6, 10))
        do {
            let drafts = try await AISettings.currentService.generateQuiz(
                subject: topic.name,
                count: clamped,
                material: topicMaterialText(for: topic, context: context),
                difficulty: difficulty
            )
            guard !drafts.isEmpty else { return "Couldn't generate questions from that material — try again." }

            let session = QuizSession(subject: topic.name, totalQuestions: drafts.count)
            context.insert(session)
            for (index, draft) in drafts.enumerated() {
                context.insert(QuizQuestion(
                    sortIndex: index,
                    text: draft.text,
                    type: draft.type,
                    choices: draft.choices,
                    correctAnswer: draft.correctAnswer,
                    session: session
                ))
            }
            pendingQuizSession = session
            let difficultyNote = difficulty.map { " (\($0))" } ?? ""
            return "Put together a \(drafts.count)-question quiz on \(topic.name)\(difficultyNote), pulled from your assignments and notes — opening it now."
        } catch {
            return "Couldn't generate the quiz: \(error.localizedDescription)"
        }
    }

    private func logQuizScore(score: Int?, total: Int?, note: String?, topic: Topic, context: ModelContext) -> String {
        guard let score, let total, total > 0, score >= 0 else {
            return "I need a valid score and total (e.g. 8 out of 10) to log this."
        }
        let trimmedNote = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        let subject = (trimmedNote?.isEmpty == false) ? "\(topic.name) — \(trimmedNote!)" : topic.name
        let session = QuizSession(subject: subject, isSubmitted: true, score: score, totalQuestions: total)
        context.insert(session)
        return "Logged \(score)/\(total) for \(subject) — it'll show up in past tests and mastery."
    }

    // MARK: - Tool definitions (provider-specific shapes, same two tools)

    private static let anthropicTools: [[String: Any]] = [
        [
            "name": "generate_quiz",
            "description": "Generate (or regenerate) a practice quiz for this topic from its logged assignments/notes, and open it for the student to take. Call this when they ask to be tested/quizzed, or to make the last quiz harder/easier.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "count": ["type": "integer", "description": "Number of questions, 3-10. Defaults to 6 if omitted."] as [String: Any],
                    "difficulty": ["type": "string", "description": "Difficulty steer in the student's own words, e.g. \"harder than last time\", \"easier / more basic\". Omit for normal difficulty."] as [String: Any],
                ] as [String: Any],
                "required": [String](),
            ] as [String: Any],
        ],
        [
            "name": "log_quiz_score",
            "description": "Log a real test/quiz score the student took outside the app (e.g. an in-class test) so it counts toward this topic's mastery stats and past-tests history.",
            "input_schema": [
                "type": "object",
                "properties": [
                    "score": ["type": "integer", "description": "Number of questions/points they got right."] as [String: Any],
                    "total": ["type": "integer", "description": "Total number of questions/points possible."] as [String: Any],
                    "note": ["type": "string", "description": "Optional short label, e.g. \"in-class pop quiz\"."] as [String: Any],
                ] as [String: Any],
                "required": ["score", "total"],
            ] as [String: Any],
        ],
    ]

    private static let openAITools: [[String: Any]] = [
        [
            "type": "function",
            "function": [
                "name": "generate_quiz",
                "description": "Generate (or regenerate) a practice quiz for this topic from its logged assignments/notes, and open it for the student to take. Call this when they ask to be tested/quizzed, or to make the last quiz harder/easier.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "count": ["type": "integer", "description": "Number of questions, 3-10. Defaults to 6 if omitted."] as [String: Any],
                        "difficulty": ["type": "string", "description": "Difficulty steer in the student's own words, e.g. \"harder than last time\", \"easier / more basic\". Omit for normal difficulty."] as [String: Any],
                    ] as [String: Any],
                    "required": [String](),
                ] as [String: Any],
            ] as [String: Any],
        ],
        [
            "type": "function",
            "function": [
                "name": "log_quiz_score",
                "description": "Log a real test/quiz score the student took outside the app (e.g. an in-class test) so it counts toward this topic's mastery stats and past-tests history.",
                "parameters": [
                    "type": "object",
                    "properties": [
                        "score": ["type": "integer", "description": "Number of questions/points they got right."] as [String: Any],
                        "total": ["type": "integer", "description": "Total number of questions/points possible."] as [String: Any],
                        "note": ["type": "string", "description": "Optional short label, e.g. \"in-class pop quiz\"."] as [String: Any],
                    ] as [String: Any],
                    "required": ["score", "total"],
                ] as [String: Any],
            ] as [String: Any],
        ],
    ]
}

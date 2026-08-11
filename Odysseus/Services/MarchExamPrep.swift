//
//  MarchExamPrep.swift
//  Odysseus
//
//  The AI side of My Tests > March Exams: gathers everything logged for a
//  class — assignments, tests/quizzes and their scores, materials, notes,
//  and how each topic's spaced-repetition review is pacing — and asks the
//  active AI provider to find weak spots and suggest what to focus on
//  before the exam. One-shot (no chat history), same pattern as the
//  homework-help / "help me understand" calls elsewhere in School.
//

import Foundation
import SwiftData

enum MarchExamPrep {
    /// Everything logged for a class, flattened into plain text for the AI
    /// — the same material a student would actually study from.
    static func buildContext(for schoolClass: SchoolClass, modelContext: ModelContext) -> String {
        var lines: [String] = []
        lines.append("Class: \(schoolClass.name) (\(schoolClass.courseLevel.displayName) level)")
        if let percent = schoolClass.calculatedPercent {
            lines.append("Current overall grade: \(String(format: "%.1f", percent))%" + (schoolClass.calculatedGradeLabel.map { " (\($0))" } ?? ""))
        }

        let topicIDs = Set(schoolClass.topics.map(\.id))
        let lessonIDs = Set(schoolClass.topics.flatMap(\.lessons).map(\.id))
        let allNotes = (try? modelContext.fetch(FetchDescriptor<Note>())) ?? []
        let topicNotesAll = allNotes.filter { $0.contextTypeRaw == "topic" && topicIDs.contains($0.contextID ?? "") }
        let lessonNotesAll = allNotes.filter { $0.contextTypeRaw == "lesson" && lessonIDs.contains($0.contextID ?? "") }
        let notes = topicNotesAll + lessonNotesAll

        for topic in schoolClass.topics.sorted(by: { $0.sortIndex < $1.sortIndex }) {
            lines.append("\nTopic: \(topic.name)")
            for lesson in topic.lessons.sorted(by: { $0.sortIndex < $1.sortIndex }) {
                lines.append("  Lesson: \(lesson.title)")
                for assignment in lesson.assignments {
                    let kind = assignment.isQuiz ? "Test/Quiz" : "Assignment"
                    let score = assignment.scoreLabel.map { " — scored \($0)" } ?? (assignment.isDone ? " — done, unscored" : " — not done")
                    lines.append("    [\(kind)] \(assignment.title)\(score)")
                }
                for material in lesson.materials {
                    lines.append("    [Material: \(material.kind.displayName)] \(material.title)")
                }
            }
            let topicNotes = notes.filter { $0.contextID == topic.id }
            for note in topicNotes {
                lines.append("  Note (\(topic.name)): \(note.title) — \(note.content.prefix(200))")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Asks the active AI provider to find weak spots and suggest what to
    /// focus on, given everything logged for the class.
    static func analyzeWeaknesses(for schoolClass: SchoolClass, modelContext: ModelContext) async throws -> String {
        let context = buildContext(for: schoolClass, modelContext: modelContext)
        let prompt = """
        Here's everything logged for this class so far, ahead of the March Exam (final):

        \(context)

        Based on this, identify the topics/lessons that look weakest (low or missing scores, thin material, no notes) and the ones that are in good shape. Give a short, specific study plan — what to focus review time on first, and roughly how the remaining time before the exam should be split across topics. Keep it concrete and actionable, not generic advice.
        """
        return try await AISettings.currentService.askAboutImage(
            prompt: prompt,
            imageData: nil,
            systemPrompt: "You are a sharp, encouraging study coach helping a student prepare for a cumulative final exam. Be specific about which topics need work and why, based only on the data given — don't invent topics that weren't mentioned."
        )
    }
}

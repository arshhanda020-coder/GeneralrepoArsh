//
//  QuizSession.swift
//  Odysseus
//
//  One "Test Me" attempt: a locked set of questions on a subject, graded on
//  submit, kept around so past scores and self-reflections can be reviewed.
//

import Foundation
import SwiftData

@Model
final class QuizSession {
    var id: String = UUID().uuidString
    var subject: String = ""
    var createdAt: Date = Date.now
    var isSubmitted: Bool = false
    var score: Int = 0
    var totalQuestions: Int = 0

    @Relationship(deleteRule: .cascade, inverse: \QuizQuestion.session)
    var questions: [QuizQuestion] = []

    init(
        id: String = UUID().uuidString,
        subject: String,
        createdAt: Date = .now,
        isSubmitted: Bool = false,
        score: Int = 0,
        totalQuestions: Int = 0
    ) {
        self.id = id
        self.subject = subject
        self.createdAt = createdAt
        self.isSubmitted = isSubmitted
        self.score = score
        self.totalQuestions = totalQuestions
    }
}

enum QuizQuestionType: String, Codable {
    case multipleChoice
    case shortAnswer
}

@Model
final class QuizQuestion {
    var id: String = UUID().uuidString
    var sortIndex: Int = 0
    var text: String = ""
    var typeRaw: String = QuizQuestionType.shortAnswer.rawValue
    /// Empty for short-answer questions.
    var choices: [String] = []
    var correctAnswer: String = ""
    var userAnswer: String?
    var isCorrect: Bool?
    /// AI grading feedback — mainly meaningful for short-answer questions.
    var feedback: String?
    /// The user's own answer to "how will you prepare/make this better?" for anything they got wrong.
    var improvementPlan: String?
    var session: QuizSession?

    init(
        id: String = UUID().uuidString,
        sortIndex: Int,
        text: String,
        type: QuizQuestionType,
        choices: [String] = [],
        correctAnswer: String,
        session: QuizSession? = nil
    ) {
        self.id = id
        self.sortIndex = sortIndex
        self.text = text
        self.typeRaw = type.rawValue
        self.choices = choices
        self.correctAnswer = correctAnswer
        self.session = session
    }

    var type: QuizQuestionType {
        get { QuizQuestionType(rawValue: typeRaw) ?? .shortAnswer }
        set { typeRaw = newValue.rawValue }
    }
}

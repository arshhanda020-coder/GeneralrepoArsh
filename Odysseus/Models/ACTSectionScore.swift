//
//  ACTSectionScore.swift
//  Odysseus
//

import Foundation
import SwiftData

enum ACTTestType: String, Codable, CaseIterable, Identifiable {
    case diagnostic
    case practice
    case official

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .diagnostic: return "Diagnostic"
        case .practice: return "Practice Test"
        case .official: return "Official Test"
        }
    }
}

@Model
final class ACTSectionScore {
    var id: String = UUID().uuidString
    var exam: Exam?
    var testTypeRaw: String = ACTTestType.practice.rawValue
    var takenAt: Date = Date.now
    var englishScore: Int?
    var mathScore: Int?
    var readingScore: Int?
    var scienceScore: Int?
    var compositeScore: Int?
    var notes: String?

    init(
        id: String = UUID().uuidString,
        exam: Exam? = nil,
        testType: ACTTestType,
        takenAt: Date = .now,
        englishScore: Int? = nil,
        mathScore: Int? = nil,
        readingScore: Int? = nil,
        scienceScore: Int? = nil,
        compositeScore: Int? = nil,
        notes: String? = nil
    ) {
        self.id = id
        self.exam = exam
        self.testTypeRaw = testType.rawValue
        self.takenAt = takenAt
        self.englishScore = englishScore
        self.mathScore = mathScore
        self.readingScore = readingScore
        self.scienceScore = scienceScore
        self.compositeScore = compositeScore
        self.notes = notes
    }

    var testType: ACTTestType {
        get { ACTTestType(rawValue: testTypeRaw) ?? .practice }
        set { testTypeRaw = newValue.rawValue }
    }

    /// Falls back to the average of the four sections if no composite was entered directly.
    var effectiveComposite: Int? {
        if let compositeScore { return compositeScore }
        let scores = [englishScore, mathScore, readingScore, scienceScore].compactMap { $0 }
        guard !scores.isEmpty else { return nil }
        return Int((Double(scores.reduce(0, +)) / Double(scores.count)).rounded())
    }
}

//
//  StudyProgress.swift
//  Odysseus
//
//  A simple leveling/XP read on School activity — no separate ledger to
//  keep in sync, it's derived live from what's already logged (study
//  sessions, topics reviewed, graded work, exam scores), so it can't drift
//  out of date with the real data.
//

import Foundation
import SwiftData

enum StudyProgress {
    struct Stats {
        let xp: Int
        let level: Int
        let xpIntoLevel: Int
        let xpPerLevel: Int
        var progress: Double { Double(xpIntoLevel) / Double(xpPerLevel) }
    }

    private static let xpPerLevel = 100
    private static let xpPerSession = 10
    private static let xpPerReview = 15
    private static let xpPerGradedItem = 5
    private static let xpPerScoredExam = 50

    static func stats(modelContext: ModelContext) -> Stats {
        let sessionCount = (try? modelContext.fetch(FetchDescriptor<StudySession>()))?.count ?? 0
        let reviewCount = ((try? modelContext.fetch(FetchDescriptor<Topic>())) ?? []).reduce(0) { $0 + $1.reviewCount }
        let gradedCount = ((try? modelContext.fetch(FetchDescriptor<Assignment>())) ?? []).filter(\.isGraded).count
        let scoredExamCount = ((try? modelContext.fetch(FetchDescriptor<Exam>())) ?? []).filter(\.hasScore).count

        let xp = sessionCount * xpPerSession
            + reviewCount * xpPerReview
            + gradedCount * xpPerGradedItem
            + scoredExamCount * xpPerScoredExam

        let level = xp / xpPerLevel + 1
        return Stats(xp: xp, level: level, xpIntoLevel: xp % xpPerLevel, xpPerLevel: xpPerLevel)
    }
}

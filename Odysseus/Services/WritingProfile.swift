//
//  WritingProfile.swift
//  Odysseus
//
//  A short real writing sample from the user, collected once, so every AI
//  drafting feature (emails, extracurricular descriptions, etc.) can match
//  their actual voice/grammar/vocabulary instead of sounding generic.
//

import Foundation

nonisolated enum WritingProfile {
    private static let sampleKey = "writing_sample_v1"
    private static let answeredKey = "writing_sample_answered_v1"

    static let prompt = "Write a few sentences about anything — your day, a hobby, an opinion, whatever comes to mind. There's no wrong answer; this just teaches the AI your natural voice."

    static var sample: String? {
        get { UserDefaults.standard.string(forKey: sampleKey) }
        set { UserDefaults.standard.set(newValue, forKey: sampleKey) }
    }

    static var hasAnswered: Bool {
        UserDefaults.standard.bool(forKey: answeredKey)
    }

    static func save(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        sample = trimmed.isEmpty ? nil : trimmed
        UserDefaults.standard.set(true, forKey: answeredKey)
    }

    /// Appended to any system prompt that generates text on the user's behalf.
    static var styleInstruction: String {
        guard let sample, !sample.isEmpty else { return "" }
        return "\n\nHere is a real writing sample from the user, so you can match their natural voice, vocabulary level, and grammar instead of sounding generic or overly formal: \"\(sample)\""
    }
}

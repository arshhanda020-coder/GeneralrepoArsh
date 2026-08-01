//
//  EmailDraft.swift
//  ArshHabitTracker
//
//  A pending, reviewable email — Jarvis/Copilot can generate a batch of these
//  (e.g. outreach to several people) but never sends anything itself; the
//  user fills in the recipient, edits if needed, and sends each one from Emails.
//

import Foundation
import SwiftData

@Model
final class EmailDraft {
    var id: String
    /// e.g. "Accountant #1" — a hint for who this copy is meant for, not an address.
    var recipientLabel: String
    var to: String
    var subject: String
    var body: String
    var isSent: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        recipientLabel: String = "",
        to: String = "",
        subject: String,
        body: String,
        isSent: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.recipientLabel = recipientLabel
        self.to = to
        self.subject = subject
        self.body = body
        self.isSent = isSent
        self.createdAt = createdAt
    }
}

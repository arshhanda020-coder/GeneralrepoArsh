//
//  ChatMessage.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class ChatMessage: @unchecked Sendable {
    var id: String
    /// "user" or "assistant"
    var role: String
    var content: String
    var createdAt: Date
    /// Optional image attached by the user (JPEG), sent to Claude as vision input.
    var imageData: Data?

    init(
        id: String = UUID().uuidString,
        role: String,
        content: String,
        createdAt: Date = .now,
        imageData: Data? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.createdAt = createdAt
        self.imageData = imageData
    }
}

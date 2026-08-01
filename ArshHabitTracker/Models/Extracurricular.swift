//
//  Extracurricular.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class Extracurricular {
    var id: String
    var title: String
    var activityDescription: String
    /// Free-form, e.g. "Finance/Research", "Volunteering".
    var category: String?
    /// True when Jarvis/Copilot created this from a chat request rather than the user typing it in directly.
    var isAISuggested: Bool
    var createdAt: Date

    init(
        id: String = UUID().uuidString,
        title: String,
        activityDescription: String = "",
        category: String? = nil,
        isAISuggested: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.activityDescription = activityDescription
        self.category = category
        self.isAISuggested = isAISuggested
        self.createdAt = createdAt
    }
}

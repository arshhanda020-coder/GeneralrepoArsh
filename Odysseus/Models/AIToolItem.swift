//
//  AIToolItem.swift
//  Odysseus
//

import Foundation
import SwiftData

enum AIToolCategory: String, Codable {
    /// Corporate tech press — TechCrunch/VentureBeat-style coverage.
    case news
    /// Community-discovered finds — Reddit/Hacker News threads about new
    /// tools, prompting tricks, agentic workflows, things people stumbled
    /// onto, not press releases.
    case innovation
    /// Generated from a GitHub link the user saved — an AI-written overview
    /// plus Claude Code install directions.
    case savedRepo
}

@Model
final class AIToolItem {
    @Attribute(.unique) var id: String
    var title: String
    var link: String
    var source: String
    var publishedAt: Date
    var snippet: String?
    var fetchedAt: Date
    var categoryRaw: String
    /// Only set for .savedRepo items — Claude Code skill-install directions.
    var installDirections: String?
    var isStarred: Bool = false

    var category: AIToolCategory { AIToolCategory(rawValue: categoryRaw) ?? .news }

    init(
        id: String,
        title: String,
        link: String,
        source: String,
        publishedAt: Date,
        snippet: String? = nil,
        fetchedAt: Date = .now,
        category: AIToolCategory = .news,
        installDirections: String? = nil,
        isStarred: Bool = false
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.source = source
        self.publishedAt = publishedAt
        self.snippet = snippet
        self.fetchedAt = fetchedAt
        self.categoryRaw = category.rawValue
        self.installDirections = installDirections
        self.isStarred = isStarred
    }
}

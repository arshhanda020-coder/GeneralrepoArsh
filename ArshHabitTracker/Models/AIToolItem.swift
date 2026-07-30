//
//  AIToolItem.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class AIToolItem {
    @Attribute(.unique) var id: String
    var title: String
    var link: String
    var source: String
    var publishedAt: Date
    var snippet: String?
    var fetchedAt: Date

    init(
        id: String,
        title: String,
        link: String,
        source: String,
        publishedAt: Date,
        snippet: String? = nil,
        fetchedAt: Date = .now
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.source = source
        self.publishedAt = publishedAt
        self.snippet = snippet
        self.fetchedAt = fetchedAt
    }
}

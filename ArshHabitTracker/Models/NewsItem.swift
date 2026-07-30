//
//  NewsItem.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class NewsItem {
    /// "<topic>::<normalized title>" — used as the dedupe key within a topic.
    @Attribute(.unique) var id: String
    var title: String
    var link: String
    var source: String
    var publishedAt: Date
    var snippet: String?
    var fetchedAt: Date
    var topicRaw: String

    init(
        id: String,
        title: String,
        link: String,
        source: String,
        publishedAt: Date,
        snippet: String? = nil,
        fetchedAt: Date = .now,
        topic: NewsTopic
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.source = source
        self.publishedAt = publishedAt
        self.snippet = snippet
        self.fetchedAt = fetchedAt
        self.topicRaw = topic.rawValue
    }

    var topic: NewsTopic {
        get { NewsTopic(rawValue: topicRaw) ?? .ai }
        set { topicRaw = newValue.rawValue }
    }
}

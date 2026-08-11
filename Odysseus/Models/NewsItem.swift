//
//  NewsItem.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class NewsItem {
    /// "<topic>::<normalized title>" — used as the dedupe key within a topic.
    // CloudKit doesn't support unique constraints; dedup is handled at the
    // call site (NewsView.merge) by checking `id` before inserting.
    var id: String = UUID().uuidString
    var title: String = ""
    var link: String = ""
    var source: String = ""
    var publishedAt: Date = Date.now
    var snippet: String?
    var fetchedAt: Date = Date.now
    var topicRaw: String = NewsTopic.ai.rawValue
    var isStarred: Bool = false

    init(
        id: String,
        title: String,
        link: String,
        source: String,
        publishedAt: Date,
        snippet: String? = nil,
        fetchedAt: Date = .now,
        topic: NewsTopic,
        isStarred: Bool = false
    ) {
        self.id = id
        self.title = title
        self.link = link
        self.source = source
        self.publishedAt = publishedAt
        self.snippet = snippet
        self.fetchedAt = fetchedAt
        self.topicRaw = topic.rawValue
        self.isStarred = isStarred
    }

    var topic: NewsTopic {
        get { NewsTopic(rawValue: topicRaw) ?? .ai }
        set { topicRaw = newValue.rawValue }
    }
}

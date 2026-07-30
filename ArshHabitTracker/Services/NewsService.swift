//
//  NewsService.swift
//  ArshHabitTracker
//

import Foundation

struct NewsFetchResult {
    let items: [FetchedNewsItem]
    let hadFailures: Bool
}

/// Fetches headlines for a topic's RSS feeds using URLSession + XMLParser only.
actor NewsService {
    static let shared = NewsService()

    private init() {}

    func fetchAll(topic: NewsTopic) async -> NewsFetchResult {
        var allItems: [FetchedNewsItem] = []
        var failures = 0

        await withTaskGroup(of: [FetchedNewsItem]?.self) { group in
            for feed in topic.feeds {
                group.addTask {
                    await self.fetchFeed(urlString: feed.url, source: feed.source)
                }
            }
            for await result in group {
                if let result {
                    allItems.append(contentsOf: result)
                } else {
                    failures += 1
                }
            }
        }

        let sorted = allItems.sorted { $0.publishedAt > $1.publishedAt }
        var seen = Set<String>()
        var deduped: [FetchedNewsItem] = []
        for item in sorted {
            if seen.insert(item.dedupeKey).inserted {
                deduped.append(item)
            }
        }

        return NewsFetchResult(items: deduped, hadFailures: failures > 0)
    }

    private func fetchFeed(urlString: String, source: String) async -> [FetchedNewsItem]? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
                return nil
            }
            return RSSParser().parse(data: data, source: source)
        } catch {
            return nil
        }
    }
}

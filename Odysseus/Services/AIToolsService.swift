//
//  AIToolsService.swift
//  Odysseus
//
//  Two distinct feeds for the AI Tools section:
//  - News: corporate tech press (TechCrunch/VentureBeat/The Verge), RSS-based.
//  - Innovation: community-discovered finds from Hacker News and Lobsters —
//    new tools, prompting tricks, agentic workflows, things people actually
//    stumbled onto, not press releases. TikTok/Twitter/Instagram need
//    developer API access this app doesn't have, and Reddit's .json
//    endpoints hard-block unauthenticated requests (confirmed via direct
//    testing — 403 regardless of User-Agent), so HN + Lobsters are the
//    closest free, no-auth sources to "what people find on the internet."
//

import Foundation

actor AIToolsService {
    static let shared = AIToolsService()

    private let newsFeeds: [(url: String, source: String)] = [
        ("https://techcrunch.com/category/artificial-intelligence/feed/", "TechCrunch"),
        ("https://venturebeat.com/category/ai/feed/", "VentureBeat"),
        ("https://www.theverge.com/rss/ai-artificial-intelligence/index.xml", "The Verge"),
    ]

    private init() {}

    func fetchNews() async -> NewsFetchResult {
        var allItems: [FetchedNewsItem] = []
        var failures = 0
        await withTaskGroup(of: [FetchedNewsItem]?.self) { group in
            for feed in newsFeeds {
                group.addTask { await self.fetchRSSFeed(urlString: feed.url, source: feed.source) }
            }
            for await result in group {
                if let result { allItems.append(contentsOf: result) } else { failures += 1 }
            }
        }
        return dedupedResult(allItems, hadFailures: failures > 0)
    }

    func fetchInnovation() async -> NewsFetchResult {
        var allItems: [FetchedNewsItem] = []
        var failures = 0
        await withTaskGroup(of: [FetchedNewsItem]?.self) { group in
            group.addTask { await self.fetchHackerNews() }
            group.addTask { await self.fetchLobsters() }
            for await result in group {
                if let result { allItems.append(contentsOf: result) } else { failures += 1 }
            }
        }
        return dedupedResult(allItems, hadFailures: failures > 0)
    }

    private func dedupedResult(_ items: [FetchedNewsItem], hadFailures: Bool) -> NewsFetchResult {
        let sorted = items.sorted { $0.publishedAt > $1.publishedAt }
        var seen = Set<String>()
        var deduped: [FetchedNewsItem] = []
        for item in sorted where seen.insert(item.dedupeKey).inserted {
            deduped.append(item)
        }
        return NewsFetchResult(items: deduped, hadFailures: hadFailures)
    }

    private func fetchRSSFeed(urlString: String, source: String) async -> [FetchedNewsItem]? {
        guard let url = URL(string: urlString) else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            return RSSParser().parse(data: data, source: source)
        } catch {
            return nil
        }
    }

    private func fetchLobsters() async -> [FetchedNewsItem]? {
        guard let url = URL(string: "https://lobste.rs/t/ai.json") else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let stories = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return nil }
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            let fallbackFormatter = ISO8601DateFormatter()
            return stories.compactMap { story -> FetchedNewsItem? in
                guard let title = story["title"] as? String, !title.isEmpty,
                      let commentsURL = story["comments_url"] as? String else { return nil }
                let link = (story["url"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? commentsURL
                let createdAtString = story["created_at"] as? String ?? ""
                let createdAt = formatter.date(from: createdAtString) ?? fallbackFormatter.date(from: createdAtString) ?? .now
                let score = story["score"] as? Int ?? 0
                let description = (story["description_plain"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let snippet = (description?.isEmpty == false) ? String(description!.prefix(220)) : (score > 0 ? "\(score) points" : nil)
                return FetchedNewsItem(title: title, link: link, source: "Lobsters", publishedAt: createdAt, snippet: snippet)
            }
        } catch {
            return nil
        }
    }

    private func fetchHackerNews() async -> [FetchedNewsItem]? {
        guard let url = URL(string: "https://hn.algolia.com/api/v1/search_by_date?tags=story&query=AI%20OR%20Claude%20OR%20GPT%20OR%20LLM&hitsPerPage=20") else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let hits = json["hits"] as? [[String: Any]] else { return nil }
            let formatter = ISO8601DateFormatter()
            return hits.compactMap { hit -> FetchedNewsItem? in
                guard let title = hit["title"] as? String, !title.isEmpty,
                      let objectID = hit["objectID"] as? String else { return nil }
                let link = (hit["url"] as? String) ?? "https://news.ycombinator.com/item?id=\(objectID)"
                let createdAt = (hit["created_at"] as? String).flatMap { formatter.date(from: $0) } ?? .now
                let points = hit["points"] as? Int ?? 0
                return FetchedNewsItem(
                    title: title,
                    link: link,
                    source: "Hacker News",
                    publishedAt: createdAt,
                    snippet: points > 0 ? "\(points) points" : nil
                )
            }
        } catch {
            return nil
        }
    }
}

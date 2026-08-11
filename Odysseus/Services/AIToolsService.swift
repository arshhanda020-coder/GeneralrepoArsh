//
//  AIToolsService.swift
//  Odysseus
//
//  Two distinct feeds for the AI Tools section:
//  - News: corporate tech press (TechCrunch/VentureBeat/The Verge), RSS-based.
//  - Innovation: new AI models, agentic workflows, and GitHub repos with
//    fresh Claude/agent tooling — sourced from Hacker News + Lobsters
//    discussion and a GitHub repo search, not press releases.
//    TikTok/Twitter/Instagram need developer API access this app doesn't
//    have, and Reddit's .json endpoints hard-block unauthenticated requests
//    (confirmed via direct testing — 403 regardless of User-Agent), so
//    HN + Lobsters + GitHub are the closest free, no-auth sources.
//    Every Innovation item is guaranteed a real one-line summary of what it
//    is — AIIntegrationView fills in AI-written ones where a source doesn't
//    hand us usable description text (see AIIntegrationView.generateSummary).
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
            group.addTask { await self.fetchGitHubRepos() }
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

    /// New GitHub repos worth knowing about — Claude tooling, MCP servers,
    /// agentic-workflow frameworks — via GitHub's unauthenticated repo search,
    /// filtered to repos pushed in the last two weeks so this stays "new,"
    /// not just perpetually-popular. Repo descriptions double as the summary;
    /// AIIntegrationView.generateSummary fills in an AI one-liner for the
    /// (rare) repo with no description.
    private func fetchGitHubRepos() async -> [FetchedNewsItem]? {
        let sinceDate = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-14 * 86400)).prefix(10)
        let query = "(claude-code OR \"claude agent\" OR agentic OR ai-agent OR mcp-server OR llm-agent) pushed:>\(sinceDate)"
        guard let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://api.github.com/search/repositories?q=\(encodedQuery)&sort=stars&order=desc&per_page=15") else { return nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else { return nil }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let repos = json["items"] as? [[String: Any]] else { return nil }
            let formatter = ISO8601DateFormatter()
            return repos.compactMap { repo -> FetchedNewsItem? in
                guard let fullName = repo["full_name"] as? String,
                      let htmlURL = repo["html_url"] as? String else { return nil }
                let pushedAt = (repo["pushed_at"] as? String).flatMap { formatter.date(from: $0) } ?? .now
                let description = (repo["description"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
                let stars = repo["stargazers_count"] as? Int ?? 0
                let language = repo["language"] as? String
                var snippet: String?
                if let description, !description.isEmpty {
                    snippet = language.map { "\(description) (\($0), \(stars)★)" } ?? "\(description) (\(stars)★)"
                }
                return FetchedNewsItem(title: fullName, link: htmlURL, source: "GitHub", publishedAt: pushedAt, snippet: snippet)
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

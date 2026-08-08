//
//  GitHubService.swift
//  Odysseus
//
//  Uses a GitHub personal access token (simpler than a full OAuth App for a
//  personal-use app) to list the user's repositories via the REST API.
//

import Foundation

actor GitHubService {
    static let shared = GitHubService()

    struct Repo: Identifiable, Decodable {
        let id: Int
        let name: String
        let fullName: String
        let description: String?
        let htmlURL: String
        let updatedAt: String
        let language: String?
        let stargazersCount: Int
        let isPrivate: Bool

        enum CodingKeys: String, CodingKey {
            case id, name, description, language
            case fullName = "full_name"
            case htmlURL = "html_url"
            case updatedAt = "updated_at"
            case stargazersCount = "stargazers_count"
            case isPrivate = "private"
        }
    }

    enum GitHubError: LocalizedError {
        case notConnected
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Add a GitHub personal access token in GitHub settings."
            case .requestFailed(let message):
                return message
            }
        }
    }

    /// Lightweight metadata for an arbitrary public repo — no auth needed,
    /// used for saved links that aren't necessarily the user's own repos.
    struct PublicRepoInfo: Decodable {
        let fullName: String
        let description: String?
        let language: String?
        let stargazersCount: Int
        let topics: [String]?

        enum CodingKeys: String, CodingKey {
            case description, language, topics
            case fullName = "full_name"
            case stargazersCount = "stargazers_count"
        }
    }

    private init() {}

    func fetchRepos(accountID: String) async throws -> [Repo] {
        guard let token = KeychainService.shared.loadGitHubToken(accountID: accountID), !token.isEmpty else {
            throw GitHubError.notConnected
        }

        var request = URLRequest(url: URL(string: "https://api.github.com/user/repos?sort=updated&per_page=30")!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GitHubError.requestFailed("GitHub returned an error — check the token's permissions.")
        }
        return try JSONDecoder().decode([Repo].self, from: data)
    }

    /// Extracts owner/repo from any github.com URL shape and fetches its
    /// public metadata. No token required — works for repos you don't own.
    func fetchPublicRepoInfo(forURL urlString: String) async throws -> PublicRepoInfo {
        guard let ownerRepo = Self.ownerRepo(fromURL: urlString),
              let url = URL(string: "https://api.github.com/repos/\(ownerRepo)") else {
            throw GitHubError.requestFailed("That doesn't look like a github.com repo link.")
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GitHubError.requestFailed("Couldn't find that repository.")
        }
        return try JSONDecoder().decode(PublicRepoInfo.self, from: data)
    }

    private static func ownerRepo(fromURL urlString: String) -> String? {
        guard let url = URL(string: urlString.trimmingCharacters(in: .whitespacesAndNewlines)),
              url.host?.contains("github.com") == true else { return nil }
        let parts = url.pathComponents.filter { $0 != "/" }
        guard parts.count >= 2 else { return nil }
        return "\(parts[0])/\(parts[1])"
    }
}

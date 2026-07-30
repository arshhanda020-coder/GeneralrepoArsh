//
//  GitHubService.swift
//  ArshHabitTracker
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

    private init() {}

    func fetchRepos() async throws -> [Repo] {
        guard let token = KeychainService.shared.loadGitHubToken(), !token.isEmpty else {
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
}

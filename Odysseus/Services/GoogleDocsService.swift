//
//  GoogleDocsService.swift
//  Odysseus
//
//  Lists the user's Google Docs via the Drive API and pulls one doc's text
//  via the Docs API, using the access token GoogleDocsAuthManager holds.
//  Read-only — this app never writes back to Google Docs.
//

import Foundation

actor GoogleDocsService {
    static let shared = GoogleDocsService()

    struct DocSummary: Identifiable, Decodable {
        let id: String
        let name: String
        let modifiedTime: String

        var modifiedDate: Date {
            ISO8601DateFormatter().date(from: modifiedTime) ?? .now
        }
    }

    private struct DriveListResponse: Decodable {
        let files: [DocSummary]
    }

    enum GoogleDocsError: LocalizedError {
        case notConnected
        case requestFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Connect a Google account in Notes settings first."
            case .requestFailed(let message):
                return message
            }
        }
    }

    /// Lists Google Docs the user owns or can access, newest-edited first.
    func listDocs() async throws -> [DocSummary] {
        guard let token = await GoogleDocsAuthManager.shared.validAccessToken() else {
            throw GoogleDocsError.notConnected
        }

        var components = URLComponents(string: "https://www.googleapis.com/drive/v3/files")!
        components.queryItems = [
            URLQueryItem(name: "q", value: "mimeType='application/vnd.google-apps.document' and trashed=false"),
            URLQueryItem(name: "fields", value: "files(id,name,modifiedTime)"),
            URLQueryItem(name: "orderBy", value: "modifiedTime desc"),
            URLQueryItem(name: "pageSize", value: "50"),
        ]
        var request = URLRequest(url: components.url!)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response, data: data)
        return try JSONDecoder().decode(DriveListResponse.self, from: data).files
    }

    /// Fetches one doc's plain-text content by flattening the Docs API's
    /// structural JSON (paragraphs of text runs) into a single string.
    func fetchContent(documentID: String) async throws -> String {
        guard let token = await GoogleDocsAuthManager.shared.validAccessToken() else {
            throw GoogleDocsError.notConnected
        }

        let url = URL(string: "https://docs.googleapis.com/v1/documents/\(documentID)")!
        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)
        try Self.checkResponse(response, data: data)

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { return "" }
        return Self.flattenText(from: json)
    }

    /// Google's document JSON nests text in `body.content[].paragraph.elements[].textRun.content`.
    /// This walks just that shape rather than pulling in a full Docs model —
    /// the API returns far more (tables, images, styling) than a read-only
    /// note import needs.
    private static func flattenText(from json: [String: Any]) -> String {
        guard let body = json["body"] as? [String: Any],
              let content = body["content"] as? [[String: Any]] else { return "" }

        var lines: [String] = []
        for block in content {
            guard let paragraph = block["paragraph"] as? [String: Any],
                  let elements = paragraph["elements"] as? [[String: Any]] else { continue }
            var line = ""
            for element in elements {
                guard let textRun = element["textRun"] as? [String: Any],
                      let text = textRun["content"] as? String else { continue }
                line += text
            }
            if !line.isEmpty { lines.append(line) }
        }
        return lines.joined().trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func checkResponse(_ response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else { return }
        guard (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String }
                ?? "Google Docs request failed (\(http.statusCode))."
            throw GoogleDocsError.requestFailed(message)
        }
    }
}

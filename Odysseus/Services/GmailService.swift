//
//  GmailService.swift
//  Odysseus
//
//  Sends email via the Gmail REST API using the OAuth access token from
//  GmailAuthManager. No third-party SDK — Gmail's send endpoint takes a
//  base64url-encoded RFC 2822 message.
//

import Foundation

actor GmailService {
    static let shared = GmailService()

    enum GmailError: LocalizedError {
        case notConnected
        case sendFailed(String)

        var errorDescription: String? {
            switch self {
            case .notConnected:
                return "Connect your Gmail account first (gear icon in Emails)."
            case .sendFailed(let message):
                return message
            }
        }
    }

    private init() {}

    func send(to: String, subject: String, body: String, accountID: String) async throws {
        guard let accessToken = await GmailAuthManager.shared.validAccessToken(accountID: accountID) else {
            throw GmailError.notConnected
        }

        let raw = Self.buildRawMessage(to: to, subject: subject, body: body)
        var request = URLRequest(url: URL(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/send")!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: ["raw": raw])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            let message = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])
                .flatMap { ($0["error"] as? [String: Any])?["message"] as? String } ?? "Gmail send failed."
            throw GmailError.sendFailed(message)
        }
    }

    private static func buildRawMessage(to: String, subject: String, body: String) -> String {
        let message = "To: \(to)\r\nSubject: \(subject)\r\nContent-Type: text/plain; charset=\"UTF-8\"\r\n\r\n\(body)"
        return Data(message.utf8).base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

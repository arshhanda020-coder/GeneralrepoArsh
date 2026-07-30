//
//  KeychainService.swift
//  ArshHabitTracker
//
//  On-device Keychain storage for every third-party credential the app holds
//  (Anthropic API key, Gmail OAuth tokens, GitHub PAT). Nothing here is ever
//  written to UserDefaults, logs, or source.
//

import Foundation
import Security

final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.traderforge.ArshHabitTracker.anthropic"

    private init() {}

    // MARK: - Generic storage

    private func save(_ data: Data, account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)

        var attributes = query
        attributes[kSecValueData as String] = data
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return data
    }

    private func delete(account: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func saveString(_ value: String, account: String) { save(Data(value.utf8), account: account) }
    private func loadString(account: String) -> String? { load(account: account).flatMap { String(data: $0, encoding: .utf8) } }

    // MARK: - Anthropic

    func loadAPIKey() -> String? { loadString(account: "api-key") }
    func saveAPIKey(_ key: String) { saveString(key, account: "api-key") }
    func deleteAPIKey() { delete(account: "api-key") }

    // MARK: - GitHub

    func loadGitHubToken() -> String? { loadString(account: "github-pat") }
    func saveGitHubToken(_ token: String) { saveString(token, account: "github-pat") }
    func deleteGitHubToken() { delete(account: "github-pat") }

    // MARK: - Gmail

    func loadGmailClientID() -> String? { loadString(account: "gmail-client-id") }
    func saveGmailClientID(_ id: String) { saveString(id, account: "gmail-client-id") }

    func loadGmailRefreshToken() -> String? { loadString(account: "gmail-refresh-token") }
    func saveGmailRefreshToken(_ token: String) { saveString(token, account: "gmail-refresh-token") }
    func deleteGmailRefreshToken() {
        delete(account: "gmail-refresh-token")
        delete(account: "gmail-access-token")
    }

    func saveGmailAccessToken(_ token: String, expiresIn: Int) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        let payload: [String: Any] = ["token": token, "expiresAt": expiresAt.timeIntervalSince1970]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        save(data, account: "gmail-access-token")
    }

    func loadGmailAccessTokenIfValid() -> String? {
        guard let data = load(account: "gmail-access-token"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let expiresAt = json["expiresAt"] as? Double,
              Date().timeIntervalSince1970 < expiresAt else { return nil }
        return token
    }
}

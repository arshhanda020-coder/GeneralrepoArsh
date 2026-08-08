//
//  KeychainService.swift
//  Odysseus
//
//  On-device Keychain storage for every third-party credential the app holds
//  (Anthropic API key, Gmail OAuth tokens, GitHub PAT). Nothing here is ever
//  written to UserDefaults, logs, or source.
//
//  Items are marked synchronizable so they ride along with the user's iCloud
//  Keychain (when they have that enabled in system Settings) — the same API
//  keys/tokens show up on iPhone and Mac instead of needing to be re-entered
//  per device. This is opt-in on Apple's end: with iCloud Keychain off,
//  these items just behave like plain on-device Keychain storage.
//

import Foundation
import Security

nonisolated final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.traderforge.Odysseus.anthropic"

    private init() {}

    // MARK: - Generic storage

    /// Items saved before sync support was added have no `kSecAttrSynchronizable`
    /// flag set at all (Keychain treats that as "local-only"). Searches use
    /// `kSecAttrSynchronizableAny` so those pre-existing items are still found —
    /// a query that instead pinned `= true` would silently miss them and make
    /// every saved key/token look deleted. Each item migrates to synchronizable
    /// automatically the next time it's saved (delete-then-insert-as-synced).
    private func save(_ data: Data, account: String) {
        let searchQuery: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(searchQuery as CFDictionary)

        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: true,
            kSecValueData as String: data,
        ]
        SecItemAdd(attributes as CFDictionary, nil)
    }

    private func load(account: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
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
            kSecAttrSynchronizable as String: kSecAttrSynchronizableAny,
        ]
        SecItemDelete(query as CFDictionary)
    }

    private func saveString(_ value: String, account: String) { save(Data(value.utf8), account: account) }
    private func loadString(account: String) -> String? { load(account: account).flatMap { String(data: $0, encoding: .utf8) } }

    // MARK: - Anthropic

    func loadAPIKey() -> String? { loadString(account: "api-key") }
    func saveAPIKey(_ key: String) { saveString(key, account: "api-key") }
    func deleteAPIKey() { delete(account: "api-key") }

    // MARK: - OpenAI

    func loadOpenAIKey() -> String? { loadString(account: "openai-api-key") }
    func saveOpenAIKey(_ key: String) { saveString(key, account: "openai-api-key") }
    func deleteOpenAIKey() { delete(account: "openai-api-key") }

    // MARK: - ElevenLabs (voice)

    func loadElevenLabsKey() -> String? { loadString(account: "elevenlabs-api-key") }
    func saveElevenLabsKey(_ key: String) { saveString(key, account: "elevenlabs-api-key") }
    func deleteElevenLabsKey() { delete(account: "elevenlabs-api-key") }

    // MARK: - GitHub (multi-account — School/Personal/etc, switchable)

    func loadGitHubToken(accountID: String) -> String? { loadString(account: "github-pat-\(accountID)") }
    func saveGitHubToken(_ token: String, accountID: String) { saveString(token, account: "github-pat-\(accountID)") }
    func deleteGitHubToken(accountID: String) { delete(account: "github-pat-\(accountID)") }

    /// The app used to support exactly one GitHub token before multi-account
    /// support — only used by GitHubAccountStore's one-time migration.
    func loadLegacyGitHubToken() -> String? { loadString(account: "github-pat") }
    func deleteLegacyGitHubToken() { delete(account: "github-pat") }

    // MARK: - Gmail (client ID is shared app-wide; tokens are per-account)

    func loadGmailClientID() -> String? { loadString(account: "gmail-client-id") }
    func saveGmailClientID(_ id: String) { saveString(id, account: "gmail-client-id") }

    func loadGmailRefreshToken(accountID: String) -> String? { loadString(account: "gmail-refresh-token-\(accountID)") }
    func saveGmailRefreshToken(_ token: String, accountID: String) { saveString(token, account: "gmail-refresh-token-\(accountID)") }
    func deleteGmailRefreshToken(accountID: String) {
        delete(account: "gmail-refresh-token-\(accountID)")
        delete(account: "gmail-access-token-\(accountID)")
    }

    func saveGmailAccessToken(_ token: String, expiresIn: Int, accountID: String) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        let payload: [String: Any] = ["token": token, "expiresAt": expiresAt.timeIntervalSince1970]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        save(data, account: "gmail-access-token-\(accountID)")
    }

    func loadGmailAccessTokenIfValid(accountID: String) -> String? {
        guard let data = load(account: "gmail-access-token-\(accountID)"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let expiresAt = json["expiresAt"] as? Double,
              Date().timeIntervalSince1970 < expiresAt else { return nil }
        return token
    }

    /// The app used to support exactly one Gmail connection before
    /// multi-account support — only used by GmailAccountStore's migration.
    func loadLegacyGmailRefreshToken() -> String? { loadString(account: "gmail-refresh-token") }
    func deleteLegacyGmailTokens() {
        delete(account: "gmail-refresh-token")
        delete(account: "gmail-access-token")
    }

    // MARK: - Dev agent bridge (Claude Code / Codex companion service)

    func loadBridgeToken(kind: String) -> String? { loadString(account: "bridge-token-\(kind)") }
    func saveBridgeToken(_ token: String, kind: String) { saveString(token, account: "bridge-token-\(kind)") }
    func deleteBridgeToken(kind: String) { delete(account: "bridge-token-\(kind)") }

    // MARK: - Google Docs (shares the Gmail OAuth client ID app-wide — same
    // Google Cloud project, just a wider scope grant — but keeps its own
    // token pair since it's a separate consent/connection from Gmail).

    func loadGoogleDocsRefreshToken() -> String? { loadString(account: "googledocs-refresh-token") }
    func saveGoogleDocsRefreshToken(_ token: String) { saveString(token, account: "googledocs-refresh-token") }
    func deleteGoogleDocsRefreshToken() {
        delete(account: "googledocs-refresh-token")
        delete(account: "googledocs-access-token")
    }

    func saveGoogleDocsAccessToken(_ token: String, expiresIn: Int) {
        let expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
        let payload: [String: Any] = ["token": token, "expiresAt": expiresAt.timeIntervalSince1970]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        save(data, account: "googledocs-access-token")
    }

    func loadGoogleDocsAccessTokenIfValid() -> String? {
        guard let data = load(account: "googledocs-access-token"),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let token = json["token"] as? String,
              let expiresAt = json["expiresAt"] as? Double,
              Date().timeIntervalSince1970 < expiresAt else { return nil }
        return token
    }

    // MARK: - App lock

    func loadPIN() -> String? { loadString(account: "app-pin") }
    func savePIN(_ pin: String) { saveString(pin, account: "app-pin") }
    func deletePIN() { delete(account: "app-pin") }

    // MARK: - One-time sync migration

    /// Existing items only pick up the synchronizable flag when they're next
    /// saved (see `save(_:account:)`). Fixed-name secrets like the API keys
    /// might otherwise never get rewritten, so force one read+rewrite per
    /// known account on first launch after this update — after that they
    /// ride iCloud Keychain like everything else. Per-account-ID secrets
    /// (GitHub PATs, Gmail/bridge tokens) aren't covered here since their IDs
    /// aren't known statically, but they get rewritten naturally on the next
    /// token refresh or re-auth.
    func migrateFixedSecretsToSynchronizableIfNeeded() {
        let key = "keychain_migrated_synchronizable_v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)

        let fixedAccounts = [
            "api-key", "openai-api-key", "elevenlabs-api-key",
            "gmail-client-id", "googledocs-refresh-token", "googledocs-access-token",
            "app-pin",
        ]
        for account in fixedAccounts {
            guard let data = load(account: account) else { continue }
            save(data, account: account)
        }
    }
}

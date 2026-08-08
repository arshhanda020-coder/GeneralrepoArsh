//
//  GmailAccountStore.swift
//  Odysseus
//
//  Named Gmail account slots (e.g. "School", "Personal") — each one is a
//  separate Google sign-in (its own refresh/access token pair in Keychain),
//  sharing the single app-level OAuth client ID. Mirrors GitHubAccountStore.
//

import Foundation

struct GmailAccount: Identifiable, Codable, Equatable {
    let id: String
    var name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}

nonisolated enum GmailAccountStore {
    private static let accountsKey = "gmail_accounts_v1"
    private static let activeAccountKey = "gmail_active_account_id"
    private static let migratedKey = "gmail_accounts_migrated_v1"

    static var accounts: [GmailAccount] {
        get {
            migrateLegacyIfNeeded()
            guard let data = UserDefaults.standard.data(forKey: accountsKey),
                  let decoded = try? JSONDecoder().decode([GmailAccount].self, from: data) else {
                return []
            }
            return decoded
        }
        set {
            let data = try? JSONEncoder().encode(newValue)
            UserDefaults.standard.set(data, forKey: accountsKey)
        }
    }

    static var activeAccountID: String? {
        get {
            migrateLegacyIfNeeded()
            return UserDefaults.standard.string(forKey: activeAccountKey) ?? accounts.first?.id
        }
        set { UserDefaults.standard.set(newValue, forKey: activeAccountKey) }
    }

    static var activeAccount: GmailAccount? {
        accounts.first { $0.id == activeAccountID }
    }

    @discardableResult
    static func addAccount(name: String) -> GmailAccount {
        let account = GmailAccount(name: name)
        var current = accounts
        current.append(account)
        accounts = current
        if activeAccountID == nil {
            activeAccountID = account.id
        }
        return account
    }

    static func removeAccount(_ account: GmailAccount) {
        KeychainService.shared.deleteGmailRefreshToken(accountID: account.id)
        var current = accounts
        current.removeAll { $0.id == account.id }
        accounts = current
        if activeAccountID == account.id {
            activeAccountID = current.first?.id
        }
    }

    /// One-time migration: the app used to support exactly one Gmail
    /// connection. Anyone already connected gets a "Personal" account seeded
    /// with that refresh token instead of silently losing the connection.
    /// Also seeds an empty "School" slot by default, per the original request.
    private static func migrateLegacyIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        UserDefaults.standard.set(true, forKey: migratedKey)

        var existing = (UserDefaults.standard.data(forKey: accountsKey))
            .flatMap { try? JSONDecoder().decode([GmailAccount].self, from: $0) } ?? []
        var activeID = UserDefaults.standard.string(forKey: activeAccountKey)

        if let legacyRefreshToken = KeychainService.shared.loadLegacyGmailRefreshToken(), !legacyRefreshToken.isEmpty {
            let account = GmailAccount(name: "Personal")
            existing.append(account)
            activeID = account.id
            KeychainService.shared.saveGmailRefreshToken(legacyRefreshToken, accountID: account.id)
            KeychainService.shared.deleteLegacyGmailTokens()
        }

        for defaultName in ["School", "Personal"] where !existing.contains(where: { $0.name == defaultName }) {
            existing.append(GmailAccount(name: defaultName))
        }
        if activeID == nil { activeID = existing.first?.id }

        UserDefaults.standard.set(try? JSONEncoder().encode(existing), forKey: accountsKey)
        UserDefaults.standard.set(activeID, forKey: activeAccountKey)
    }
}

//
//  GitHubAccountStore.swift
//  Odysseus
//
//  Named GitHub PAT slots (e.g. "School", "Personal") so repos from more than
//  one account can be browsed — each account's token lives in Keychain,
//  keyed by that account's id; only the account list + which one is active
//  live in UserDefaults (no secrets there).
//

import Foundation

struct GitHubAccount: Identifiable, Codable, Equatable {
    let id: String
    var name: String

    init(id: String = UUID().uuidString, name: String) {
        self.id = id
        self.name = name
    }
}

nonisolated enum GitHubAccountStore {
    private static let accountsKey = "github_accounts_v1"
    private static let activeAccountKey = "github_active_account_id"
    private static let migratedKey = "github_accounts_migrated_v1"

    static var accounts: [GitHubAccount] {
        get {
            migrateLegacyTokenIfNeeded()
            guard let data = UserDefaults.standard.data(forKey: accountsKey),
                  let decoded = try? JSONDecoder().decode([GitHubAccount].self, from: data) else {
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
            migrateLegacyTokenIfNeeded()
            return UserDefaults.standard.string(forKey: activeAccountKey) ?? accounts.first?.id
        }
        set { UserDefaults.standard.set(newValue, forKey: activeAccountKey) }
    }

    static var activeAccount: GitHubAccount? {
        accounts.first { $0.id == activeAccountID }
    }

    @discardableResult
    static func addAccount(name: String) -> GitHubAccount {
        let account = GitHubAccount(name: name)
        var current = accounts
        current.append(account)
        accounts = current
        if activeAccountID == nil {
            activeAccountID = account.id
        }
        return account
    }

    static func removeAccount(_ account: GitHubAccount) {
        KeychainService.shared.deleteGitHubToken(accountID: account.id)
        var current = accounts
        current.removeAll { $0.id == account.id }
        accounts = current
        if activeAccountID == account.id {
            activeAccountID = current.first?.id
        }
    }

    /// One-time migration: the app used to support exactly one GitHub token.
    /// Anyone with that legacy token gets a "Personal" account seeded with it
    /// instead of silently losing their connection. On top of that, this
    /// seeds empty "School"/"Personal" slots by default (whichever aren't
    /// already present) so those two named slots exist from the start,
    /// per the original request, rather than requiring "Add an account" first.
    private static func migrateLegacyTokenIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: migratedKey) else { return }
        UserDefaults.standard.set(true, forKey: migratedKey)

        var existing = (UserDefaults.standard.data(forKey: accountsKey))
            .flatMap { try? JSONDecoder().decode([GitHubAccount].self, from: $0) } ?? []
        var activeID = UserDefaults.standard.string(forKey: activeAccountKey)

        if let legacyToken = KeychainService.shared.loadLegacyGitHubToken(), !legacyToken.isEmpty {
            let account = GitHubAccount(name: "Personal")
            existing.append(account)
            activeID = account.id
            KeychainService.shared.saveGitHubToken(legacyToken, accountID: account.id)
            KeychainService.shared.deleteLegacyGitHubToken()
        }

        for defaultName in ["School", "Personal"] where !existing.contains(where: { $0.name == defaultName }) {
            existing.append(GitHubAccount(name: defaultName))
        }
        if activeID == nil { activeID = existing.first?.id }

        UserDefaults.standard.set(try? JSONEncoder().encode(existing), forKey: accountsKey)
        UserDefaults.standard.set(activeID, forKey: activeAccountKey)
    }
}

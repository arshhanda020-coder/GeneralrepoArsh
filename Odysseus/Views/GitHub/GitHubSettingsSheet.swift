//
//  GitHubSettingsSheet.swift
//  Odysseus
//
//  Named GitHub PAT slots (School, Personal, etc) instead of a single token —
//  each has its own field here, and GitHubView's dropdown switches which
//  one's repos are shown.
//

import SwiftUI

struct GitHubSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var accounts: [GitHubAccount] = GitHubAccountStore.accounts
    @State private var tokens: [String: String] = [:]
    @State private var newAccountName = ""

    var body: some View {
        NavigationStack {
            Form {
                if accounts.isEmpty {
                    Section {
                        Text("No accounts yet. Add one below — e.g. \"School\" and \"Personal\" — each with its own token.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    }
                }

                ForEach(accounts) { account in
                    Section(account.name) {
                        SecureField("ghp_...", text: binding(for: account))
                            .platformAutocapitalization(.never)
                            .autocorrectionDisabled()
                        Button("Remove \(account.name)", role: .destructive) {
                            removeAccount(account)
                        }
                    }
                }

                Section("Add an account") {
                    TextField("Name (e.g. School, Personal)", text: $newAccountName)
                        .platformAutocapitalization(.words)
                        .onSubmit { addAccount() }
                    Button("Add") {
                        addAccount()
                    }
                    .disabled(newAccountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                Section {
                    Text("Create a token at github.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens. Grant read-only access to repository contents and metadata.")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
            }
            .navigationTitle("GitHub Settings")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .onAppear(perform: populateTokens)
        }
    }

    private func binding(for account: GitHubAccount) -> Binding<String> {
        Binding(
            get: { tokens[account.id] ?? "" },
            set: { tokens[account.id] = $0 }
        )
    }

    private func populateTokens() {
        for account in accounts {
            tokens[account.id] = KeychainService.shared.loadGitHubToken(accountID: account.id) ?? ""
        }
    }

    private func addAccount() {
        let name = newAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        let account = GitHubAccountStore.addAccount(name: name)
        accounts = GitHubAccountStore.accounts
        tokens[account.id] = ""
        newAccountName = ""
    }

    private func removeAccount(_ account: GitHubAccount) {
        GitHubAccountStore.removeAccount(account)
        accounts = GitHubAccountStore.accounts
        tokens[account.id] = nil
    }

    private func save() {
        for account in accounts {
            let trimmed = (tokens[account.id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                KeychainService.shared.deleteGitHubToken(accountID: account.id)
            } else {
                KeychainService.shared.saveGitHubToken(trimmed, accountID: account.id)
            }
        }
        dismiss()
    }
}

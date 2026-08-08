//
//  GmailSettingsSheet.swift
//  Odysseus
//

import SwiftUI

struct GmailSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var clientID: String = KeychainService.shared.loadGmailClientID() ?? ""
    @State private var accounts: [GmailAccount] = GmailAccountStore.accounts
    @State private var newAccountName = ""

    private var urlScheme: String? {
        guard let prefix = clientID.split(separator: "-").first, !prefix.isEmpty else { return nil }
        return "com.googleusercontent.apps.\(prefix)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Accounts") {
                    ForEach(accounts) { account in
                        HStack {
                            Text(account.name)
                            Spacer()
                            if KeychainService.shared.loadGmailRefreshToken(accountID: account.id) != nil {
                                Text("Connected").font(.caption2).foregroundStyle(Theme.terminalGreen)
                            }
                        }
                    }
                    .onDelete(perform: removeAccounts)
                    HStack {
                        TextField("Name (e.g. School, Personal)", text: $newAccountName)
                            .platformAutocapitalization(.words)
                            .onSubmit { addAccount() }
                        Button("Add") { addAccount() }
                            .disabled(newAccountName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                    Text("This just manages the named slots — connect/disconnect each one from the \"Gmail account\" section back in Emails.")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }

                Section("Google OAuth client ID") {
                    TextField("xxxxx.apps.googleusercontent.com", text: $clientID)
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Create one at console.cloud.google.com → APIs & Services → Credentials → Create Credentials → OAuth client ID → iOS. Enable the Gmail API on the project first.")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }

                if let urlScheme {
                    Section("One-time Xcode setup required") {
                        Text("Add a URL Type in the Xcode target (Target → Info → URL Types → +) with this exact URL Scheme, then rebuild:")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                        Text(urlScheme)
                            .font(.system(.caption, design: .monospaced))
                            .textSelection(.enabled)
                            .padding(8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Theme.background)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
            .navigationTitle("Gmail Settings")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        KeychainService.shared.saveGmailClientID(clientID.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onSubmit {
                guard !clientID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                KeychainService.shared.saveGmailClientID(clientID.trimmingCharacters(in: .whitespacesAndNewlines))
                dismiss()
            }
        }
    }

    private func addAccount() {
        let name = newAccountName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        GmailAccountStore.addAccount(name: name)
        accounts = GmailAccountStore.accounts
        newAccountName = ""
    }

    private func removeAccounts(at offsets: IndexSet) {
        for index in offsets {
            GmailAccountStore.removeAccount(accounts[index])
        }
        accounts = GmailAccountStore.accounts
    }
}

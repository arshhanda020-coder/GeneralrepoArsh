//
//  GitHubSettingsSheet.swift
//  ArshHabitTracker
//

import SwiftUI

struct GitHubSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var token: String = KeychainService.shared.loadGitHubToken() ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section("GitHub personal access token") {
                    SecureField("ghp_...", text: $token)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Create one at github.com → Settings → Developer settings → Personal access tokens → Fine-grained tokens. Grant read-only access to repository contents and metadata.")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }

                if !token.isEmpty {
                    Section {
                        Button("Remove token", role: .destructive) {
                            KeychainService.shared.deleteGitHubToken()
                            token = ""
                        }
                    }
                }
            }
            .navigationTitle("GitHub Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        KeychainService.shared.saveGitHubToken(token.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(token.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

//
//  APIKeySheet.swift
//  ArshHabitTracker
//

import SwiftUI

struct APIKeySheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var key: String = KeychainService.shared.loadAPIKey() ?? ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Anthropic API key") {
                    SecureField("sk-ant-...", text: $key)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                }
                Section {
                    Text("Stored on-device in the iOS Keychain. Never leaves this device except in requests to api.anthropic.com.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
                if !key.isEmpty {
                    Section {
                        Button("Remove key", role: .destructive) {
                            KeychainService.shared.deleteAPIKey()
                            key = ""
                        }
                    }
                }
            }
            .navigationTitle("Copilot Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        KeychainService.shared.saveAPIKey(key.trimmingCharacters(in: .whitespacesAndNewlines))
                        dismiss()
                    }
                    .disabled(key.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
}

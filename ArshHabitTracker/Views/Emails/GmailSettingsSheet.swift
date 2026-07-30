//
//  GmailSettingsSheet.swift
//  ArshHabitTracker
//

import SwiftUI

struct GmailSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var clientID: String = KeychainService.shared.loadGmailClientID() ?? ""

    private var urlScheme: String? {
        guard let prefix = clientID.split(separator: "-").first, !prefix.isEmpty else { return nil }
        return "com.googleusercontent.apps.\(prefix)"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Google OAuth client ID") {
                    TextField("xxxxx.apps.googleusercontent.com", text: $clientID)
                        .textInputAutocapitalization(.never)
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
            .navigationBarTitleDisplayMode(.inline)
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
        }
    }
}

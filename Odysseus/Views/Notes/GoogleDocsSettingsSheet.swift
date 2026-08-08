//
//  GoogleDocsSettingsSheet.swift
//  Odysseus
//

import SwiftUI

struct GoogleDocsSettingsSheet: View {
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
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Shared with Gmail — if that's already set up in Emails settings, Docs reuses it automatically. Otherwise create one at console.cloud.google.com → APIs & Services → Credentials → Create Credentials → OAuth client ID → iOS, then enable the Google Drive API and Google Docs API on that project.")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }

                if let urlScheme {
                    Section("One-time Xcode setup required") {
                        Text("Add a URL Type in the Xcode target (Target → Info → URL Types → +) with this exact URL Scheme, then rebuild — the same one Gmail uses:")
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

                Section("Notability") {
                    Text("Notability has no API to connect to. Export a note from Notability (Share → PDF, RTF, or plain text) and import the file from Notes → Notability instead.")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
            }
            .navigationTitle("Notes Settings")
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
        }
    }
}

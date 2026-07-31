//
//  EmailsView.swift
//  ArshHabitTracker
//

import SwiftUI

struct EmailsView: View {
    @StateObject private var auth = GmailAuthManager.shared

    @State private var to = ""
    @State private var subject = ""
    @State private var emailBody = ""
    @State private var isSending = false
    @State private var isDrafting = false
    @State private var statusMessage: String?
    @State private var showingSettings = false

    var body: some View {
        Form {
            Section("Gmail account") {
                if auth.isConnected {
                    HStack {
                        Image(systemName: "checkmark.seal.fill").foregroundStyle(Theme.terminalGreen)
                        Text("Connected")
                        Spacer()
                        Button("Disconnect", role: .destructive) { auth.disconnect() }
                    }
                } else {
                    Button("Connect Gmail") { auth.connect() }
                }
                if let message = auth.statusMessage {
                    Text(message).font(.caption).foregroundStyle(Color(hex: "FF6B6B"))
                }
            }

            Section("Compose") {
                TextField("To", text: $to)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                TextField("Subject", text: $subject)
                TextField("Body", text: $emailBody, axis: .vertical)
                    .lineLimit(6...12)
            }

            Section {
                Button {
                    draftWithCopilot()
                } label: {
                    Label(isDrafting ? "Drafting…" : "Draft with Copilot", systemImage: "sparkles")
                }
                .disabled(isDrafting || subject.trimmingCharacters(in: .whitespaces).isEmpty)

                Button {
                    sendEmail()
                } label: {
                    Label(isSending ? "Sending…" : "Send", systemImage: "paperplane.fill")
                }
                .disabled(isSending || !auth.isConnected || to.trimmingCharacters(in: .whitespaces).isEmpty || emailBody.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            if let statusMessage {
                Section {
                    Text(statusMessage)
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Emails")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            GmailSettingsSheet()
        }
    }

    private func draftWithCopilot() {
        isDrafting = true
        statusMessage = nil
        let recipient = to.trimmingCharacters(in: .whitespaces)
        let existingDraft = emailBody.trimmingCharacters(in: .whitespaces)
        Task {
            let prompt = "Draft a concise, professional email.\nSubject: \(subject)\nRecipient: \(recipient.isEmpty ? "unspecified" : recipient)\nContext or existing draft to improve: \(existingDraft.isEmpty ? "none — write a reasonable draft from the subject alone" : existingDraft)"
            do {
                let draft = try await AISettings.currentService.draft(prompt: prompt)
                if !draft.isEmpty { emailBody = draft }
            } catch {
                statusMessage = error.localizedDescription
            }
            isDrafting = false
        }
    }

    private func sendEmail() {
        isSending = true
        statusMessage = nil
        Task {
            do {
                try await GmailService.shared.send(to: to, subject: subject, body: emailBody)
                statusMessage = "Sent."
                to = ""
                subject = ""
                emailBody = ""
            } catch {
                statusMessage = error.localizedDescription
            }
            isSending = false
        }
    }
}

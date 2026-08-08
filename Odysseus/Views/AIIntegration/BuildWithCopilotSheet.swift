//
//  BuildWithCopilotSheet.swift
//  Odysseus
//
//  "Build me" for an AI Tools Innovation find — a prefilled prompt (editable)
//  that gets sent straight into the same Copilot conversation used
//  everywhere else, so the plan Copilot writes shows up in the normal chat.
//

import SwiftUI

struct BuildWithCopilotSheet: View {
    let prompt: String

    @Environment(\.dismiss) private var dismiss
    @State private var editableText: String
    @State private var isSending = false
    @State private var didSend = false

    init(prompt: String) {
        self.prompt = prompt
        _editableText = State(initialValue: prompt)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Message to Copilot") {
                    TextField("Prompt", text: $editableText, axis: .vertical)
                        .lineLimit(6...14)
                        .onSubmit { send() }
                }
                if didSend {
                    Section {
                        Text("Sent — check Copilot for the plan.")
                            .font(.caption)
                            .foregroundStyle(Theme.terminalGreen)
                    }
                }
            }
            .navigationTitle("Build with Copilot")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isSending ? "Sending…" : "Send") { send() }
                        .disabled(isSending || didSend || editableText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func send() {
        guard !isSending, !didSend else { return }
        let trimmed = editableText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isSending = true
        Task {
            await OdysseusController.shared.sendMessage(trimmed)
            isSending = false
            didSend = true
            try? await Task.sleep(nanoseconds: 700_000_000)
            dismiss()
        }
    }
}

#Preview {
    BuildWithCopilotSheet(prompt: "I found this: \"Example tool\" (https://example.com).\nHelp me build something like this.")
}

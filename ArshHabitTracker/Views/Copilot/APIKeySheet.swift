//
//  APIKeySheet.swift
//  ArshHabitTracker
//
//  AI settings: pick the active provider (Claude or ChatGPT), its model, and
//  store each provider's API key. Every AI feature in the app reads these
//  same settings via AISettings.currentService.
//

import SwiftUI

struct APIKeySheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var provider: AIProvider = AISettings.provider
    @State private var claudeModel: String = AISettings.claudeModel
    @State private var openAIModel: String = AISettings.openAIModel
    @State private var claudeKey: String = KeychainService.shared.loadAPIKey() ?? ""
    @State private var openAIKey: String = KeychainService.shared.loadOpenAIKey() ?? ""
    @State private var showingWritingSample = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Active provider") {
                    Picker("Provider", selection: $provider) {
                        ForEach(AIProvider.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Claude") {
                    SecureField("sk-ant-...", text: $claudeKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Model", selection: $claudeModel) {
                        ForEach(AISettings.claudeModelOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    if !claudeKey.isEmpty {
                        Button("Remove Claude key", role: .destructive) {
                            KeychainService.shared.deleteAPIKey()
                            claudeKey = ""
                        }
                    }
                }

                Section("ChatGPT") {
                    SecureField("sk-...", text: $openAIKey)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Model", selection: $openAIModel) {
                        ForEach(AISettings.openAIModelOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    if !openAIKey.isEmpty {
                        Button("Remove ChatGPT key", role: .destructive) {
                            KeychainService.shared.deleteOpenAIKey()
                            openAIKey = ""
                        }
                    }
                }

                Section("Writing style") {
                    Button {
                        showingWritingSample = true
                    } label: {
                        Label(WritingProfile.sample == nil ? "Add a writing sample" : "Edit writing sample", systemImage: "text.quote")
                    }
                    Text("A short real sample of how you write, so AI drafts (emails, extracurricular descriptions) sound like you instead of generic.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }

                Section {
                    Text("Keys are stored on-device in the iOS Keychain. Only the active provider is used across Copilot, Jarvis, School, Food, and Emails.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
            }
            .navigationTitle("AI Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .sheet(isPresented: $showingWritingSample) {
                WritingSampleView()
            }
        }
    }

    private func save() {
        AISettings.provider = provider
        AISettings.claudeModel = claudeModel
        AISettings.openAIModel = openAIModel
        let trimmedClaude = claudeKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOpenAI = openAIKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedClaude.isEmpty { KeychainService.shared.saveAPIKey(trimmedClaude) }
        if !trimmedOpenAI.isEmpty { KeychainService.shared.saveOpenAIKey(trimmedOpenAI) }
        dismiss()
    }
}

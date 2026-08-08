//
//  APIKeySheet.swift
//  Odysseus
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
    @State private var elevenLabsKey: String = KeychainService.shared.loadElevenLabsKey() ?? ""
    @State private var elevenLabsVoiceID: String = ElevenLabsSettings.voiceID ?? ""
    @State private var showingWritingSample = false
    @ObservedObject private var voice = OdysseusController.shared.voice

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
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Model", selection: $claudeModel) {
                        ForEach(AISettings.claudeModelOptions, id: \.self) { option in
                            Text(option == "claude-sonnet-5" ? "\(option) (Recommended)" : option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    if !claudeKey.isEmpty {
                        Button("Remove Claude key", role: .destructive) {
                            KeychainService.shared.deleteAPIKey()
                            claudeKey = ""
                        }
                    }
                }

                Section("ChatGPT") {
                    SecureField("sk-...", text: $openAIKey)
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Picker("Model", selection: $openAIModel) {
                        ForEach(AISettings.openAIModelOptions, id: \.self) { option in
                            Text(option == "gpt-4o" ? "\(option) (Recommended)" : option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    if !openAIKey.isEmpty {
                        Button("Remove ChatGPT key", role: .destructive) {
                            KeychainService.shared.deleteOpenAIKey()
                            openAIKey = ""
                        }
                    }
                    Text("Also used as Odysseus's fallback voice if ElevenLabs isn't configured below — Claude has no text-to-speech API of its own.")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }

                Section("Odysseus's voice — ElevenLabs") {
                    SecureField("ElevenLabs API key", text: $elevenLabsKey)
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Voice ID", text: $elevenLabsVoiceID)
                        .platformAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Text("Pick a voice at elevenlabs.io (Voices → browse/preview → copy its Voice ID) and paste it here. This is the primary voice whenever both fields are filled in — the ChatGPT voice above becomes the fallback.")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                    if !elevenLabsKey.isEmpty {
                        Button("Remove ElevenLabs key", role: .destructive) {
                            KeychainService.shared.deleteElevenLabsKey()
                            elevenLabsKey = ""
                        }
                    }
                    Button {
                        let trimmedKey = elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        let trimmedVoiceID = elevenLabsVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !trimmedKey.isEmpty, !trimmedVoiceID.isEmpty else { return }
                        KeychainService.shared.saveElevenLabsKey(trimmedKey)
                        ElevenLabsSettings.voiceID = trimmedVoiceID
                        voice.speak("Hi, I'm Odysseus. This is what I sound like now.")
                    } label: {
                        Label(voice.isSpeaking ? "Speaking…" : "Preview Odysseus's voice", systemImage: "play.circle")
                    }
                    .disabled(voice.isSpeaking
                        || elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        || elevenLabsVoiceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let statusMessage = voice.statusMessage {
                        Text(statusMessage)
                            .font(.caption2)
                            .foregroundStyle(Color(hex: "FF6B6B"))
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
                    Text("Keys are stored on-device in the iOS Keychain. Only the active provider is used across Copilot, Odysseus, School, Food, and Emails.")
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                }
            }
            .navigationTitle("AI Settings")
            .inlineNavigationTitle()
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
        let trimmedElevenLabsKey = elevenLabsKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedVoiceID = elevenLabsVoiceID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedClaude.isEmpty { KeychainService.shared.saveAPIKey(trimmedClaude) }
        if !trimmedOpenAI.isEmpty { KeychainService.shared.saveOpenAIKey(trimmedOpenAI) }
        if !trimmedElevenLabsKey.isEmpty { KeychainService.shared.saveElevenLabsKey(trimmedElevenLabsKey) }
        if !trimmedVoiceID.isEmpty { ElevenLabsSettings.voiceID = trimmedVoiceID }
        dismiss()
    }
}

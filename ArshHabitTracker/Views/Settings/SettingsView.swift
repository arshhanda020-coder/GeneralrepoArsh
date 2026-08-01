//
//  SettingsView.swift
//  ArshHabitTracker
//
//  One place for everything configurable: AI keys/models, integrations,
//  appearance, writing style, and the PIN.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var showingAI = false
    @State private var showingGitHub = false
    @State private var showingGmail = false
    @State private var showingWritingSample = false
    @State private var showingChangePIN = false

    var body: some View {
        NavigationStack {
            Form {
                Section("AI") {
                    Button {
                        showingAI = true
                    } label: {
                        Label("Claude / ChatGPT keys & models", systemImage: "key")
                    }
                    Button {
                        showingWritingSample = true
                    } label: {
                        Label("Writing style sample", systemImage: "text.quote")
                    }
                }

                Section("Integrations") {
                    Button {
                        showingGitHub = true
                    } label: {
                        Label("GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Button {
                        showingGmail = true
                    } label: {
                        Label("Gmail", systemImage: "envelope")
                    }
                }

                Section("Appearance") {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("Colors", systemImage: "paintpalette")
                    }
                }

                Section("Security") {
                    Button {
                        showingChangePIN = true
                    } label: {
                        Label("Change PIN", systemImage: "lock")
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .sheet(isPresented: $showingAI) { APIKeySheet() }
        .sheet(isPresented: $showingGitHub) { GitHubSettingsSheet() }
        .sheet(isPresented: $showingGmail) { GmailSettingsSheet() }
        .sheet(isPresented: $showingWritingSample) { WritingSampleView() }
        .fullScreenCover(isPresented: $showingChangePIN) { ChangePINView() }
    }
}

#Preview {
    SettingsView()
}

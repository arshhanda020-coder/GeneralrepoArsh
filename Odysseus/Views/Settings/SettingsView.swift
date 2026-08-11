//
//  SettingsView.swift
//  Odysseus
//
//  One place for everything configurable: AI keys/models, integrations,
//  appearance, writing style, and the PIN.
//

import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    #if os(iOS)
    @StateObject private var healthKit = HealthKitManager.shared
    #endif

    @State private var showingAI = false
    @State private var showingGitHub = false
    @State private var showingGmail = false
    @State private var showingWritingSample = false
    @State private var showingChangePIN = false
    @State private var showingDeleteConfirmation = false
    @State private var didDeleteAll = false
    @State private var biometricKind = BiometricAuthService.shared.availableKind
    @State private var biometricUnlockEnabled = BiometricLockSettings.isEnabled

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
                    #if os(iOS)
                    Button {
                        showingGmail = true
                    } label: {
                        Label("Gmail", systemImage: "envelope")
                    }
                    Button {
                        Task { await healthKit.requestAuthorizationAndRefresh() }
                    } label: {
                        Label(healthKit.isAuthorized ? "Apple Health — Connected" : "Connect Apple Health", systemImage: "heart.fill")
                    }
                    if let steps = healthKit.todaysSteps {
                        Text("\(steps) steps today")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    }
                    if let message = healthKit.statusMessage {
                        Text(message)
                            .font(.caption)
                            .foregroundStyle(Theme.negative)
                    }
                    #endif
                }

                Section("Appearance") {
                    NavigationLink(destination: AppearanceSettingsView()) {
                        Label("Colors", systemImage: "paintpalette")
                    }
                }

                Section("Notifications") {
                    NavigationLink(destination: NotificationSettingsView()) {
                        Label("Reminders & alerts", systemImage: "bell.badge")
                    }
                }

                Section {
                    Button {
                        showingChangePIN = true
                    } label: {
                        Label("Change PIN", systemImage: "lock")
                    }
                    if let biometricKind {
                        Toggle(isOn: $biometricUnlockEnabled) {
                            Label("Unlock with \(biometricKind.label)", systemImage: biometricKind.systemImage)
                        }
                        .onChange(of: biometricUnlockEnabled) { _, newValue in
                            BiometricLockSettings.isEnabled = newValue
                        }
                    }
                } header: {
                    Text("Security")
                } footer: {
                    if let biometricKind {
                        Text("Your PIN still works either way — this just offers \(biometricKind.label) first on the lock screen.")
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete All Data", systemImage: "trash")
                    }
                    if didDeleteAll {
                        Text("All data deleted.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    }
                } header: {
                    Text("Danger Zone")
                } footer: {
                    Text("Permanently deletes every project, school record, health entry, news item, and chat — everything tracked in the app. Your API keys, PIN, and appearance settings are not affected.")
                }
            }
            .navigationTitle("Settings")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Delete all data?",
                isPresented: $showingDeleteConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    deleteAllData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently deletes everything tracked in the app — projects, school records, health entries, news, chats. This can't be undone.")
            }
        }
        .sheet(isPresented: $showingAI) { APIKeySheet() }
        .sheet(isPresented: $showingGitHub) { GitHubSettingsSheet() }
        #if os(iOS)
        .sheet(isPresented: $showingGmail) { GmailSettingsSheet() }
        #endif
        .sheet(isPresented: $showingWritingSample) { WritingSampleView() }
        .platformFullScreenCover(isPresented: $showingChangePIN) { ChangePINView() }
    }

    private func deleteAllData() {
        let types: [any PersistentModel.Type] = [
            FoodEntry.self, WorkoutEntry.self,
            Skill.self, SkillSession.self,
            Project.self, ProjectTask.self,
            NewsItem.self, ChatMessage.self, ChatSession.self,
            AIToolItem.self, Exam.self, StudySession.self,
            Assignment.self, QuizSession.self, QuizQuestion.self, SchoolClass.self, Topic.self,
            Extracurricular.self, EmailDraft.self, GradeScaleEntry.self, GradeEntry.self,
            ProgressEntry.self, MonthlyReport.self, WatchedSymbol.self,
            MemoryEntry.self, ACTSectionScore.self, ACTPrepPlan.self, SavedGitHubLink.self, ResearchEntry.self, AgentDefinition.self, AgentRun.self,
            ObsidianNote.self,
        ]
        for type in types {
            try? modelContext.delete(model: type)
        }
        try? modelContext.save()
        didDeleteAll = true
    }
}

#Preview {
    SettingsView()
}

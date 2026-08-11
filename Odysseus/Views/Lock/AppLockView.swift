//
//  AppLockView.swift
//  Odysseus
//
//  Local device lock only — a 4-digit PIN stored in Keychain, checked on
//  every cold launch. Not an account/auth system; there's no server to
//  authenticate against. Face ID (iPhone) / Touch ID (Mac, iPad) is an
//  optional faster path in front of the same PIN — never a replacement for
//  it, since biometrics can be turned off in Settings or simply unavailable.
//

import SwiftUI
import SwiftData

struct AppLockView: View {
    var onUnlocked: () -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var hasPIN = KeychainService.shared.loadPIN() != nil
    @State private var entered = ""
    @State private var confirmStage = false
    @State private var firstEntry = ""
    @State private var errorMessage: String?
    @State private var showingForgotConfirmation = false
    @State private var biometricKind = BiometricAuthService.shared.availableKind
    @State private var isPromptingBiometrics = false

    private var biometricUnlockAvailable: Bool {
        hasPIN && biometricKind != nil && BiometricLockSettings.isEnabled
    }

    var body: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "lock.fill")
                .font(.system(size: 32))
                .foregroundStyle(Theme.accent)

            Text(hasPIN ? "Enter PIN" : (confirmStage ? "Confirm PIN" : "Create a PIN"))
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.primaryText)

            HStack(spacing: 16) {
                ForEach(0..<4, id: \.self) { index in
                    Circle()
                        .fill(index < entered.count ? Theme.accent : Theme.card)
                        .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
                        .frame(width: 16, height: 16)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(Theme.negative)
            }

            if biometricUnlockAvailable, let biometricKind {
                Button {
                    Task { await attemptBiometricUnlock() }
                } label: {
                    Label("Unlock with \(biometricKind.label)", systemImage: biometricKind.systemImage)
                        .font(.subheadline.weight(.medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(Theme.accent)
                .disabled(isPromptingBiometrics)
            }

            Spacer()

            keypad
                .padding(.bottom, 24)

            if hasPIN {
                Button("Forgot PIN?") {
                    showingForgotConfirmation = true
                }
                .font(.caption)
                .foregroundStyle(Theme.dimText)
                .padding(.bottom, 16)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .task {
            // Fires once when the lock screen first appears (cold launch) —
            // offer the fast path immediately instead of making the user
            // tap through to it.
            if biometricUnlockAvailable {
                await attemptBiometricUnlock()
            }
        }
        .confirmationDialog(
            "Reset PIN?",
            isPresented: $showingForgotConfirmation,
            titleVisibility: .visible
        ) {
            Button("Erase All Data & Reset PIN", role: .destructive) {
                resetEverything()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("There's no account to recover a PIN from — this is a device-only lock. The only way back in is to erase everything tracked in the app and set a new PIN.")
        }
    }

    private func attemptBiometricUnlock() async {
        guard !isPromptingBiometrics else { return }
        isPromptingBiometrics = true
        let success = await BiometricAuthService.shared.authenticate(reason: "Unlock Odysseus")
        isPromptingBiometrics = false
        if success {
            onUnlocked()
        }
        // On failure/cancel, just leave the PIN pad up — no error message,
        // since backing out of Face ID/Touch ID isn't a wrong PIN attempt.
    }

    private func resetEverything() {
        let types: [any PersistentModel.Type] = [
            FoodEntry.self, WorkoutEntry.self,
            Skill.self, SkillSession.self,
            Project.self, ProjectTask.self,
            NewsItem.self, ChatMessage.self, ChatSession.self,
            AIToolItem.self, Exam.self, StudySession.self,
            Assignment.self, QuizSession.self, QuizQuestion.self, SchoolClass.self, Topic.self,
            Lesson.self, LessonMaterial.self,
            Extracurricular.self, EmailDraft.self,
            ProgressEntry.self, MonthlyReport.self, WatchedSymbol.self,
            MemoryEntry.self, ACTSectionScore.self, ACTPrepPlan.self, APExamPrepPlan.self,
        ]
        for type in types {
            try? modelContext.delete(model: type)
        }
        try? modelContext.save()
        KeychainService.shared.deletePIN()
        hasPIN = false
        entered = ""
        confirmStage = false
        firstEntry = ""
        errorMessage = nil
    }

    private var keypad: some View {
        let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], ["", "0", "⌫"]]
        return VStack(spacing: 18) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 28) {
                    ForEach(row, id: \.self) { key in
                        keyButton(key)
                    }
                }
            }
        }
    }

    private func keyButton(_ key: String) -> some View {
        Button {
            handleKey(key)
        } label: {
            Group {
                if key == "⌫" {
                    Image(systemName: "delete.left")
                } else {
                    Text(key)
                }
            }
            .font(.title2.weight(.medium))
            .foregroundStyle(Theme.primaryText)
            .frame(width: 68, height: 68)
            .background(key.isEmpty ? Color.clear : Theme.card)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.cardBorder, lineWidth: key.isEmpty ? 0 : 1))
        }
        .buttonStyle(.plain)
        .disabled(key.isEmpty)
    }

    private func handleKey(_ key: String) {
        errorMessage = nil
        if key == "⌫" {
            if !entered.isEmpty { entered.removeLast() }
            return
        }
        guard entered.count < 4 else { return }
        entered.append(key)
        guard entered.count == 4 else { return }

        if hasPIN {
            if KeychainService.shared.loadPIN() == entered {
                onUnlocked()
            } else {
                errorMessage = "Incorrect PIN."
                entered = ""
            }
        } else if !confirmStage {
            firstEntry = entered
            entered = ""
            confirmStage = true
        } else {
            if entered == firstEntry {
                KeychainService.shared.savePIN(entered)
                onUnlocked()
            } else {
                errorMessage = "PINs didn't match — try again."
                entered = ""
                confirmStage = false
                firstEntry = ""
            }
        }
    }
}

#Preview {
    AppLockView(onUnlocked: {})
}

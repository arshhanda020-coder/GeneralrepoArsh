//
//  ProjectAgentRunSheet.swift
//  Odysseus
//
//  Runs a Claude Code / Codex prompt scoped to a project's linked repo
//  (project.repoPath) via the bridge, and logs the result as an AgentRun so
//  ProjectDetailView keeps a real history — not the one-shot request/
//  response DevAgentBridgeView shows.
//

import SwiftUI
import SwiftData

struct ProjectAgentRunSheet: View {
    @Bindable var project: Project

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var kind: DevAgentKind = .claudeCode
    @State private var bridgeURL = ""
    @State private var token = ""
    @State private var prompt = ""
    @State private var fullAuto = false
    @State private var isRunning = false
    @State private var runError: String?

    private var repoPath: String { project.repoPath?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "" }
    private var isConfigured: Bool { !bridgeURL.isEmpty && !token.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section("AGENT") {
                    Picker("Agent", selection: $kind) {
                        ForEach(DevAgentKind.allCases, id: \.self) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: kind) { _, _ in loadCredentials() }
                }

                Section("REPO") {
                    if repoPath.isEmpty {
                        Text("No repo path set for this project — add one from the project's Edit sheet first.")
                            .font(.caption)
                            .foregroundStyle(Theme.negative)
                    } else {
                        Text(repoPath)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.dimText)
                    }
                }

                if !repoPath.isEmpty && !isConfigured {
                    Section {
                        Text("\(kind.displayName) bridge isn't set up yet. Open Subagents → \(kind.displayName), save a bridge URL + token, then come back.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    }
                } else if !repoPath.isEmpty {
                    Section("PROMPT") {
                        TextField("What should \(kind.displayName) do in this repo?", text: $prompt, axis: .vertical)
                            .lineLimit(3...8)
                        Toggle("Full auto (skip permission prompts)", isOn: $fullAuto)
                    }

                    if let runError {
                        Section {
                            Text(runError)
                                .font(.caption)
                                .foregroundStyle(Theme.negative)
                        }
                    }
                }
            }
            .navigationTitle("Run Agent")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isRunning ? "Running…" : "Run") { run() }
                        .disabled(isRunning || repoPath.isEmpty || !isConfigured || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .onAppear(perform: loadCredentials)
    }

    private func loadCredentials() {
        bridgeURL = UserDefaults.standard.string(forKey: kind.bridgeURLKey) ?? ""
        token = KeychainService.shared.loadBridgeToken(kind: kind.agentKey) ?? ""
    }

    private func run() {
        isRunning = true
        runError = nil
        let submittedPrompt = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        let submittedFullAuto = fullAuto
        let submittedKind = kind
        Task {
            do {
                let result = try await DevAgentBridgeClient.run(
                    baseURL: bridgeURL,
                    token: token,
                    agent: submittedKind.agentKey,
                    prompt: submittedPrompt,
                    cwd: repoPath,
                    fullAuto: submittedFullAuto
                )
                logRun(kind: submittedKind, prompt: submittedPrompt, fullAuto: submittedFullAuto, result: result)
                isRunning = false
                if result.ok {
                    dismiss()
                } else {
                    runError = result.error ?? "Unknown error."
                }
            } catch {
                logRun(
                    kind: submittedKind, prompt: submittedPrompt, fullAuto: submittedFullAuto,
                    result: BridgeRunResult(ok: false, output: "", sessionId: nil, costUSD: nil, error: error.localizedDescription)
                )
                runError = error.localizedDescription
                isRunning = false
            }
        }
    }

    private func logRun(kind: DevAgentKind, prompt: String, fullAuto: Bool, result: BridgeRunResult) {
        let run = AgentRun(
            output: result.output,
            bridgeAgentKind: kind.agentKey,
            prompt: prompt,
            ok: result.ok,
            errorMessage: result.error,
            sessionId: result.sessionId,
            costUSD: result.costUSD,
            fullAuto: fullAuto,
            project: project
        )
        modelContext.insert(run)
    }
}

#Preview {
    ProjectAgentRunSheet(project: Project(name: "Odysseus", emoji: "🤖", colorHex: "5B8CFF", repoPath: "/Users/example/Desktop/Odysseus"))
        .modelContainer(for: [Project.self, AgentRun.self], inMemory: true)
}

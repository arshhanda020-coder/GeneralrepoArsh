//
//  AgentsView.swift
//  Odysseus
//
//  Subagents — named, reusable sets of instructions you can run on demand,
//  with a logged history of what each run produced. Styled in the same HUD
//  console language as Odysseus: monospace labels, status dots, bracket chrome.
//

import SwiftUI
import SwiftData

struct AgentsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AgentDefinition.createdAt, order: .reverse) private var agents: [AgentDefinition]

    @State private var showingNew = false
    @State private var selectedAgent: AgentDefinition?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if agents.isEmpty {
                    Text("No subagents yet. Tap + to define one — a fixed set of instructions you can run on demand, e.g. \"Weekly Research Digest\" or \"Portfolio Check-in.\"")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.dimText)
                        .padding(.top, 40)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(agents.enumerated()), id: \.element.id) { index, agent in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            row(agent)
                        }
                    }
                    .glassPanel(cornerRadius: 8)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("Subagents")
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingNew = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingNew) {
            NewAgentSheet()
        }
        .navigationDestination(item: $selectedAgent) { agent in
            AgentDetailView(agent: agent)
        }
    }

    private func row(_ agent: AgentDefinition) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(MindMapSection.agents.accentColor)
                .frame(width: 6, height: 6)
            VStack(alignment: .leading, spacing: 2) {
                Text(agent.name.uppercased())
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Text("\(agent.runs.count) run\(agent.runs.count == 1 ? "" : "s") logged")
                    .font(.system(.caption2, design: .monospaced))
                    .foregroundStyle(Theme.dimText)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
        .padding(12)
        .contentShape(Rectangle())
        .onTapGesture { selectedAgent = agent }
    }
}

private struct NewAgentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    @State private var name = ""
    @State private var instructions = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("NAME") {
                    TextField("e.g. Weekly Research Digest", text: $name)
                        .font(.system(.body, design: .monospaced))
                }
                Section("INSTRUCTIONS") {
                    TextField("What should this agent do when run?", text: $instructions, axis: .vertical)
                        .lineLimit(4...10)
                        .font(.system(.body, design: .monospaced))
                }
            }
            .navigationTitle("New Subagent")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            || instructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }

    private func save() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedInstructions = instructions.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !trimmedInstructions.isEmpty else { return }
        modelContext.insert(AgentDefinition(name: trimmedName, instructions: trimmedInstructions))
        dismiss()
    }
}

private struct AgentDetailView: View {
    let agent: AgentDefinition
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var isRunning = false
    @State private var runError: String?
    @State private var showingDeleteConfirmation = false

    private var sortedRuns: [AgentRun] { agent.runs.sorted { $0.createdAt > $1.createdAt } }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("INSTRUCTIONS")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(1)
                        .foregroundStyle(Theme.dimText)
                    Text(agent.instructions)
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(Theme.primaryText)
                }
                .padding(12)
                .glassPanel(cornerRadius: 8)

                Button {
                    run()
                } label: {
                    Label(isRunning ? "RUNNING…" : "RUN NOW", systemImage: "play.fill")
                        .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(MindMapSection.agents.accentColor)
                .disabled(isRunning)

                if let runError {
                    Text(runError).font(.system(.caption, design: .monospaced)).foregroundStyle(Color(hex: "FF6B6B"))
                }

                if !sortedRuns.isEmpty {
                    Text("RUN LOG")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(1)
                        .foregroundStyle(Theme.dimText)
                    VStack(spacing: 0) {
                        ForEach(Array(sortedRuns.enumerated()), id: \.element.id) { index, run in
                            if index > 0 {
                                Divider().overlay(Theme.cardBorder)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text(run.createdAt.formatted(.dateTime.month(.abbreviated).day().hour().minute()))
                                    .font(.system(.caption2, design: .monospaced))
                                    .foregroundStyle(Theme.dimText)
                                Text(run.output)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundStyle(Theme.primaryText)
                            }
                            .padding(10)
                        }
                    }
                    .glassPanel(cornerRadius: 8)
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(agent.name)
        .inlineNavigationTitle()
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Image(systemName: "trash")
                }
            }
        }
        .confirmationDialog("Delete this subagent?", isPresented: $showingDeleteConfirmation, titleVisibility: .visible) {
            Button("Delete", role: .destructive) {
                modelContext.delete(agent)
                dismiss()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    private func run() {
        isRunning = true
        runError = nil
        Task {
            do {
                let output = try await AgentRunner.run(instructions: agent.instructions)
                modelContext.insert(AgentRun(output: output, agent: agent))
            } catch {
                runError = error.localizedDescription
            }
            isRunning = false
        }
    }
}

#Preview {
    NavigationStack {
        AgentsView()
    }
    .modelContainer(for: [AgentDefinition.self, AgentRun.self], inMemory: true)
}

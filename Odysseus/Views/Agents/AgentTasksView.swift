//
//  AgentTasksView.swift
//  Odysseus
//
//  The dashboard half of DevAgentBridgeView — turns the bridge's task store
//  (bridge/server.js's POST /tasks + GET /tasks) into the same "Working /
//  Completed" feed the real `claude` CLI shows in its own background-task
//  view, just polled over HTTP and drawn in Odysseus's glass/HUD language
//  instead of a terminal.
//

import SwiftUI

private let pollInterval: UInt64 = 2_000_000_000 // 2s, in nanoseconds

struct AgentTasksPanel: View {
    let kind: DevAgentKind
    let bridgeURL: String
    let token: String
    let workingDirectory: String
    @Binding var fullAuto: Bool

    @State private var prompt = ""
    @State private var isSubmitting = false
    @State private var submitError: String?
    @State private var tasks: [BridgeTask] = []
    @State private var pollTask: Task<Void, Never>?
    @State private var expandedTaskId: String?

    private var workingTasks: [BridgeTask] { tasks.filter { $0.status == .working } }
    private var finishedTasks: [BridgeTask] { tasks.filter { $0.status != .working } }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            promptCard
            if !tasks.isEmpty {
                summaryLine
                taskList
            }
        }
        .task { await startPolling() }
        .onDisappear { pollTask?.cancel() }
    }

    // MARK: - Prompt input

    private var promptCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("PROMPT")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.dimText)
            TextField("What should \(kind.displayName) do in \(workingDirectory)?", text: $prompt, axis: .vertical)
                .lineLimit(3...8)
                .font(.system(.body, design: .monospaced))
                .padding(10)
                .glassPanel(cornerRadius: 8)

            Button {
                submit()
            } label: {
                Label(isSubmitting ? "STARTING…" : "RUN", systemImage: "play.fill")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(kind.accentColor)
            .disabled(isSubmitting || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let submitError {
                Text(submitError).font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.negative)
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 8)
    }

    private func submit() {
        isSubmitting = true
        submitError = nil
        let submittedPrompt = prompt
        Task {
            do {
                let task = try await DevAgentBridgeClient.startTask(
                    baseURL: bridgeURL, token: token, agent: kind.agentKey,
                    prompt: submittedPrompt, cwd: workingDirectory, fullAuto: fullAuto
                )
                tasks.insert(task, at: 0)
                prompt = ""
            } catch {
                submitError = error.localizedDescription
            }
            isSubmitting = false
        }
    }

    // MARK: - Dashboard feed

    private var summaryLine: some View {
        HStack(spacing: 4) {
            Circle().fill(Theme.terminalAmber).frame(width: 5, height: 5)
                .opacity(workingTasks.isEmpty ? 0.35 : 1)
                .modifier(PulseIf(active: !workingTasks.isEmpty))
            Text("\(workingTasks.count) WORKING · \(finishedTasks.count) COMPLETED")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.dimText)
        }
    }

    private var taskList: some View {
        VStack(spacing: 0) {
            ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                if index > 0 { Divider().overlay(Theme.cardBorder) }
                taskRow(task)
            }
        }
        .glassPanel(cornerRadius: 8, tintOpacity: 0.5)
    }

    private func taskRow(_ task: BridgeTask) -> some View {
        let isExpanded = expandedTaskId == task.id
        return VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 8) {
                statusDot(for: task.status)
                    .padding(.top, 5)
                VStack(alignment: .leading, spacing: 2) {
                    Text(task.prompt)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.primaryText)
                        .lineLimit(isExpanded ? nil : 2)
                    Text(statusDetail(for: task))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.dimText)
                }
                Spacer(minLength: 0)
                if let costUSD = task.costUSD {
                    Text(String(format: "$%.3f", costUSD))
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.dimText)
                }
            }

            if isExpanded {
                let body = task.status == .error ? (task.error ?? "Unknown error.") : task.output
                if !body.isEmpty {
                    Text(body)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(task.status == .error ? Theme.negative : Theme.primaryText)
                        .textSelection(.enabled)
                        .padding(.leading, 14)
                }
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture {
            expandedTaskId = isExpanded ? nil : task.id
        }
    }

    private func statusDot(for status: BridgeTaskStatus) -> some View {
        Circle()
            .fill(color(for: status))
            .frame(width: 6, height: 6)
            .modifier(PulseIf(active: status == .working))
    }

    private func color(for status: BridgeTaskStatus) -> Color {
        switch status {
        case .working: return Theme.terminalAmber
        case .completed: return Theme.terminalGreen
        case .error: return Theme.negative
        }
    }

    private func statusDetail(for task: BridgeTask) -> String {
        let timestamp = task.startedAt.formatted(.dateTime.month(.abbreviated).day().hour().minute())
        switch task.status {
        case .working: return "working · started \(timestamp)"
        case .completed: return "completed · \(timestamp)"
        case .error: return "error · \(timestamp)"
        }
    }

    // MARK: - Polling

    private func startPolling() async {
        pollTask?.cancel()
        pollTask = Task {
            while !Task.isCancelled {
                await refresh()
                try? await Task.sleep(nanoseconds: pollInterval)
            }
        }
    }

    private func refresh() async {
        guard !bridgeURL.isEmpty, !token.isEmpty else { return }
        if let fetched = try? await DevAgentBridgeClient.listTasks(baseURL: bridgeURL, token: token, agent: kind.agentKey) {
            tasks = fetched
        }
    }
}

/// A slow opacity breathe — the same "still working" cue the CLI's own
/// dashboard gives you with its blinking status dot, without an actual
/// terminal cursor to borrow.
private struct PulseIf: ViewModifier {
    let active: Bool
    @State private var lit = true

    func body(content: Content) -> some View {
        content
            .opacity(active ? (lit ? 1 : 0.35) : 1)
            .onAppear {
                guard active else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    lit = false
                }
            }
    }
}

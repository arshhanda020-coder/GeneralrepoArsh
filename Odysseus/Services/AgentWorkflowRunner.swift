//
//  AgentWorkflowRunner.swift
//  Odysseus
//
//  Dispatches an AgentDefinition's run to the right backend: plain chat
//  completion (AgentRunner) for `.chat`, or the real Claude Code / Codex CLI
//  via the companion bridge (DevAgentBridgeClient) for `.claudeCode`/`.codex`
//  — reusing whatever bridge URL/token the user already saved from the
//  Claude Code / Codex sections, so a workflow doesn't need its own copy.
//

import Foundation

enum AgentWorkflowError: LocalizedError {
    case bridgeNotConfigured(DevAgentKind)
    case noWorkingDirectory

    var errorDescription: String? {
        switch self {
        case .bridgeNotConfigured(let kind):
            return "\(kind.displayName) isn't connected yet — open \(kind.displayName) and set the bridge URL + token first."
        case .noWorkingDirectory:
            return "This workflow needs a working directory to run against."
        }
    }
}

enum AgentWorkflowRunner {
    static func run(_ agent: AgentDefinition) async throws -> String {
        guard let bridgeKind = agent.runKind.bridgeKind else {
            return try await AgentRunner.run(instructions: agent.instructions)
        }

        guard let workingDirectory = agent.workingDirectory?.trimmingCharacters(in: .whitespacesAndNewlines),
              !workingDirectory.isEmpty else {
            throw AgentWorkflowError.noWorkingDirectory
        }

        let bridgeURL = UserDefaults.standard.string(forKey: bridgeKind.bridgeURLKey) ?? ""
        let token = KeychainService.shared.loadBridgeToken(kind: bridgeKind.agentKey) ?? ""
        guard !bridgeURL.isEmpty, !token.isEmpty else {
            throw AgentWorkflowError.bridgeNotConfigured(bridgeKind)
        }

        // fullAuto stays off here — an unattended workflow run shouldn't be
        // able to edit files or run commands without the user watching.
        let result = try await DevAgentBridgeClient.run(
            baseURL: bridgeURL,
            token: token,
            agent: bridgeKind.agentKey,
            prompt: agent.instructions,
            cwd: workingDirectory,
            fullAuto: false
        )
        if !result.ok, let error = result.error {
            throw BridgeError.server(error)
        }
        return result.output
    }
}

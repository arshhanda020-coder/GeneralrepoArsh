//
//  DevAgentBridgeView.swift
//  Odysseus
//
//  Connects to the companion service in bridge/server.js — a small Node
//  process you run on your Mac that wraps the real `claude` (Claude Code)
//  and `codex` CLIs. There's no public mobile API for either tool, so this
//  is the bridge: point it at the Mac running server.js, paste the token it
//  printed on startup, and prompts sent from here run through the actual
//  CLI against a real working directory — not a chat-completion stand-in.
//

import SwiftUI

enum DevAgentKind {
    case claudeCode
    case codex

    var displayName: String {
        switch self {
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        }
    }

    var accentColor: Color {
        switch self {
        case .claudeCode: return MindMapSection.claudeCode.accentColor
        case .codex: return MindMapSection.codex.accentColor
        }
    }

    var bridgeURLKey: String {
        switch self {
        case .claudeCode: return "claude_code_bridge_url"
        case .codex: return "codex_bridge_url"
        }
    }

    /// Identifier the bridge server and Keychain both key on — matches the
    /// `agent` field server.js's /run endpoint expects.
    var agentKey: String {
        switch self {
        case .claudeCode: return "claudeCode"
        case .codex: return "codex"
        }
    }

    var mindMapSection: MindMapSection {
        switch self {
        case .claudeCode: return .claudeCode
        case .codex: return .codex
        }
    }
}

private struct OptionalKeyboardType: ViewModifier {
    let keyboard: PlatformKeyboardType?
    func body(content: Content) -> some View {
        if let keyboard { content.platformKeyboardType(keyboard) } else { content }
    }
}

private enum ConnectionState: Equatable {
    case unknown
    case checking
    case unreachable
    case unauthorized
    case connected(available: Bool, version: String?)
}

struct DevAgentBridgeView: View {
    let kind: DevAgentKind

    @AppStorage private var bridgeURL: String
    @State private var token: String = ""
    @State private var workingDirectory: String = NSHomeDirectory()
    @State private var fullAuto = false
    @State private var connection: ConnectionState = .unknown

    @State private var prompt = ""
    @State private var isRunning = false
    @State private var lastResult: BridgeRunResult?
    @State private var runError: String?

    init(kind: DevAgentKind) {
        self.kind = kind
        _bridgeURL = AppStorage(wrappedValue: "", kind.bridgeURLKey)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                statusCard
                setupCard
                if case .connected = connection {
                    runCard
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(kind.displayName)
        .inlineNavigationTitle()
        .sectionAssistantButton(kind.mindMapSection)
        .onAppear {
            bridgeURL = UserDefaults.standard.string(forKey: kind.bridgeURLKey) ?? bridgeURL
            token = KeychainService.shared.loadBridgeToken(kind: kind.agentKey) ?? ""
            if !bridgeURL.isEmpty, !token.isEmpty { checkConnection() }
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Circle().fill(statusColor).frame(width: 6, height: 6)
                Text(statusLabel)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .tracking(1)
                    .foregroundStyle(Theme.dimText)
                Spacer()
                if connection == .checking {
                    ProgressView().scaleEffect(0.6)
                }
            }
            Text(statusDetail)
                .font(.system(.caption2, design: .monospaced))
                .foregroundStyle(Theme.dimText)
        }
        .padding(12)
        .glassPanel(cornerRadius: 8)
    }

    private var statusColor: Color {
        switch connection {
        case .connected(let available, _): return available ? Theme.terminalGreen : Theme.terminalAmber
        case .checking: return Theme.dimText.opacity(0.5)
        case .unreachable, .unauthorized: return Theme.negative
        case .unknown: return Theme.dimText.opacity(0.5)
        }
    }

    private var statusLabel: String {
        switch connection {
        case .connected(let available, _): return available ? "CONNECTED" : "CONNECTED — \(kind.displayName.uppercased()) NOT ON MAC"
        case .checking: return "CHECKING…"
        case .unreachable: return "UNREACHABLE"
        case .unauthorized: return "BAD TOKEN"
        case .unknown: return "NOT CONNECTED"
        }
    }

    private var statusDetail: String {
        switch connection {
        case .connected(let available, let version):
            return available
                ? "Bridge reports \(kind.displayName) is installed\(version.map { " (\($0))" } ?? "") and ready."
                : "Bridge is reachable, but \(kind.displayName) isn't installed on that Mac (or not on PATH)."
        case .checking:
            return "Pinging the bridge…"
        case .unreachable:
            return "Couldn't reach \(bridgeURL.isEmpty ? "a bridge — set the URL below" : bridgeURL). Is `node server.js` running on your Mac, and is this device on the same network?"
        case .unauthorized:
            return "Bridge answered but rejected the token. Re-copy it from the server's startup output."
        case .unknown:
            return "\(kind.displayName) runs on your Mac, not on this device. Run `node bridge/server.js` on your Mac (see bridge/README.md), then fill in its URL and token below."
        }
    }

    // MARK: - Setup

    private var setupCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            labeledField(title: "BRIDGE URL", placeholder: "http://192.168.x.x:8787", text: $bridgeURL, keyboard: .url)
            labeledField(title: "TOKEN", placeholder: "printed by server.js on startup", text: $token, secure: true)
            labeledField(title: "WORKING DIRECTORY", placeholder: "/path/to/project", text: $workingDirectory)

            Toggle(isOn: $fullAuto) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("FULL AUTO").font(.system(.caption, design: .monospaced).weight(.semibold))
                    Text("Skips permission prompts — the agent can edit files and run commands without asking. Off = read-only planning.")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(Theme.dimText)
                }
            }
            .tint(kind.accentColor)

            Button {
                UserDefaults.standard.set(bridgeURL, forKey: kind.bridgeURLKey)
                KeychainService.shared.saveBridgeToken(token, kind: kind.agentKey)
                checkConnection()
            } label: {
                Text("SAVE & CONNECT")
                    .font(.system(.caption, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(kind.accentColor)
            .disabled(bridgeURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .glassPanel(cornerRadius: 8, tintOpacity: 0.5)
    }

    private func labeledField(title: String, placeholder: String, text: Binding<String>, secure: Bool = false, keyboard: PlatformKeyboardType? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.dimText)
            Group {
                if secure {
                    SecureField(placeholder, text: text)
                } else {
                    TextField(placeholder, text: text)
                }
            }
            .font(.system(.body, design: .monospaced))
            .platformAutocapitalization(.never)
            .autocorrectionDisabled()
            .modifier(OptionalKeyboardType(keyboard: keyboard))
            .padding(10)
            .glassPanel(cornerRadius: 8)
        }
    }

    private func checkConnection() {
        connection = .checking
        Task {
            let reachable = await DevAgentBridgeClient.ping(baseURL: bridgeURL)
            guard reachable else { connection = .unreachable; return }
            guard !token.isEmpty else { connection = .unauthorized; return }
            do {
                let health = try await DevAgentBridgeClient.health(baseURL: bridgeURL, token: token)
                let status = kind == .claudeCode ? health.claudeCode : health.codex
                connection = .connected(available: status.available, version: status.version)
            } catch BridgeError.unauthorized {
                connection = .unauthorized
            } catch {
                connection = .unreachable
            }
        }
    }

    // MARK: - Run

    private var runCard: some View {
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
                run()
            } label: {
                Label(isRunning ? "RUNNING…" : "RUN", systemImage: "play.fill")
                    .font(.system(.subheadline, design: .monospaced).weight(.semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(kind.accentColor)
            .disabled(isRunning || prompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if let runError {
                Text(runError).font(.system(.caption, design: .monospaced)).foregroundStyle(Theme.negative)
            }

            if let lastResult {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(lastResult.ok ? "RESULT" : "ERROR")
                            .font(.system(.caption2, design: .monospaced).weight(.bold))
                            .tracking(1)
                            .foregroundStyle(lastResult.ok ? Theme.dimText : Theme.negative)
                        Spacer()
                        if let sessionId = lastResult.sessionId {
                            Text(String(sessionId.prefix(8)))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Theme.dimText)
                        }
                        if let costUSD = lastResult.costUSD {
                            Text(String(format: "$%.3f", costUSD))
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundStyle(Theme.dimText)
                        }
                    }
                    Text(lastResult.ok ? lastResult.output : (lastResult.error ?? "Unknown error."))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(Theme.primaryText)
                        .textSelection(.enabled)
                }
                .padding(10)
                .glassPanel(cornerRadius: 8)
            }
        }
        .padding(12)
        .glassPanel(cornerRadius: 8)
    }

    private func run() {
        isRunning = true
        runError = nil
        let submittedPrompt = prompt
        Task {
            do {
                let result = try await DevAgentBridgeClient.run(
                    baseURL: bridgeURL,
                    token: token,
                    agent: kind.agentKey,
                    prompt: submittedPrompt,
                    cwd: workingDirectory,
                    fullAuto: fullAuto
                )
                lastResult = result
                if result.ok { prompt = "" }
            } catch {
                runError = error.localizedDescription
            }
            isRunning = false
        }
    }
}

#Preview {
    NavigationStack {
        DevAgentBridgeView(kind: .claudeCode)
    }
}

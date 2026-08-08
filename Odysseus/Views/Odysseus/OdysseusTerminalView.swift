//
//  OdysseusTerminalView.swift
//  Odysseus
//
//  Full-screen, voice-only Odysseus takeover — redesigned as a HUD command
//  console (corner-bracket viewport, live system-status panels either side
//  of the reactor, bottom transcript line) rather than a single centered
//  visual, modeled directly on a reference screenshot the user provided.
//

import SwiftUI
import SwiftData

struct OdysseusTerminalView: View {
    @EnvironmentObject private var odysseus: OdysseusController
    @Query(sort: \ChatMessage.createdAt, order: .reverse) private var recentMessages: [ChatMessage]
    @Query private var assignments: [Assignment]
    @Query private var projectTasks: [ProjectTask]
    @Query private var memories: [MemoryEntry]

    @State private var elapsed = 0
    @State private var timer: Timer?

    private var lastUserMessage: ChatMessage? { recentMessages.first { $0.role == "user" } }
    private var lastAssistantMessage: ChatMessage? { recentMessages.first { $0.role == "assistant" } }

    private var today: Date { Calendar.current.startOfDay(for: .now) }
    private var todayCounts: (done: Int, total: Int) {
        var done = 0, total = 0
        for assignment in assignments {
            guard let due = assignment.dueDate else { continue }
            let dueDay = Calendar.current.startOfDay(for: due)
            guard dueDay <= today, dueDay == today || !assignment.isDone else { continue }
            total += 1
            if assignment.isDone { done += 1 }
        }
        for task in projectTasks {
            guard let due = task.dueDate else { continue }
            let dueDay = Calendar.current.startOfDay(for: due)
            guard dueDay <= today, dueDay == today || !task.isDone else { continue }
            total += 1
            if task.isDone { done += 1 }
        }
        return (done, total)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            HUDCornerBrackets()

            VStack(spacing: 0) {
                header
                liveBadge
                    .padding(.top, 10)

                Spacer(minLength: 12)

                HStack(alignment: .center, spacing: 0) {
                    sidePanel(title: "TODAY", rows: todayRows)
                    Spacer(minLength: 8)
                    ArcReactorView(size: 168, isActive: odysseus.status != .idle, isSpeaking: odysseus.status == .speaking)
                    Spacer(minLength: 8)
                    sidePanel(title: "SYSTEMS", rows: systemRows)
                }
                .padding(.horizontal, 12)

                Text(statusText)
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .tracking(3)
                    .foregroundStyle(Theme.reactorCore)
                    .padding(.top, 16)

                Spacer(minLength: 12)

                subtitlesBox
                    .padding(.horizontal, 16)
                micStatusLine
                    .padding(.horizontal, 16)
                    .padding(.top, 6)
                    .padding(.bottom, 20)
            }
        }
        .onAppear {
            odysseus.expand()
            startTimer()
        }
        .onDisappear { timer?.invalidate() }
        .onChange(of: odysseus.status) { _, newValue in
            if newValue != .idle { elapsed = 0 }
        }
    }

    // MARK: - Chrome

    private var header: some View {
        HStack(alignment: .top) {
            Button {
                odysseus.collapse()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.reactorCore.opacity(0.85))
            }

            Spacer()

            VStack(spacing: 2) {
                Text("O.D.Y.S.S.E.U.S")
                    .font(.system(.caption, design: .monospaced).weight(.bold))
                    .tracking(2)
                    .foregroundStyle(Theme.reactorCore)
                Text("NEURAL LINK · CONNECTED")
                    .font(.system(size: 9, design: .monospaced))
                    .tracking(1)
                    .foregroundStyle(Theme.dimText)
            }

            Spacer()

            Button {
                odysseus.deactivate()
            } label: {
                Image(systemName: "power.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: "FF6B6B").opacity(0.85))
            }
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
    }

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(odysseus.status == .idle ? Theme.dimText : Color(hex: "FF6B6B"))
                .frame(width: 6, height: 6)
            Text(odysseus.status == .idle ? "STANDBY" : "BRIEFING · LIVE")
                .font(.system(size: 10, design: .monospaced).weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.dimText)
            Text("·")
                .foregroundStyle(Theme.dimText)
            Text(Self.timeFormatter.string(from: .now))
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.dimText)
            if odysseus.status != .idle {
                Text("·")
                    .foregroundStyle(Theme.dimText)
                Text(elapsedString)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Theme.reactorCore)
            }
        }
    }

    // MARK: - Side panels

    private struct StatusRow: Identifiable {
        let id = UUID()
        let label: String
        let value: String
        let isLive: Bool
    }

    private var todayRows: [StatusRow] {
        let counts = todayCounts
        return [
            StatusRow(label: "TASKS", value: "\(counts.done)/\(counts.total)", isLive: counts.total > 0),
            StatusRow(label: "MEMORY", value: "\(memories.count)", isLive: !memories.isEmpty),
        ]
    }

    private var systemRows: [StatusRow] {
        let aiLive = AISettings.hasActiveKey
        let voiceLabel: String
        let voiceLive: Bool
        if KeychainService.shared.loadElevenLabsKey()?.isEmpty == false && ElevenLabsSettings.voiceID?.isEmpty == false {
            voiceLabel = "11LABS"
            voiceLive = true
        } else if KeychainService.shared.loadOpenAIKey()?.isEmpty == false {
            voiceLabel = "OPENAI"
            voiceLive = true
        } else {
            voiceLabel = "SYSTEM"
            voiceLive = false
        }
        let githubConnected = GitHubAccountStore.accounts.contains { KeychainService.shared.loadGitHubToken(accountID: $0.id) != nil }
        return [
            StatusRow(label: AISettings.provider.displayName.uppercased(), value: aiLive ? "LIVE" : "OFF", isLive: aiLive),
            StatusRow(label: "VOICE", value: voiceLabel, isLive: voiceLive),
            StatusRow(label: "GITHUB", value: githubConnected ? "LIVE" : "OFF", isLive: githubConnected),
        ]
    }

    private func sidePanel(title: String, rows: [StatusRow]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 9, design: .monospaced).weight(.bold))
                .tracking(1)
                .foregroundStyle(Theme.dimText)
            ForEach(rows) { row in
                HStack(spacing: 4) {
                    Text(row.label)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Theme.dimText)
                    Spacer(minLength: 4)
                    Text(row.value)
                        .font(.system(size: 9, design: .monospaced).weight(.semibold))
                        .foregroundStyle(row.isLive ? Theme.terminalGreen : Theme.dimText)
                }
            }
        }
        .padding(8)
        .frame(width: 84, alignment: .leading)
        .glassPanel(cornerRadius: 6, tintOpacity: 0.6)
    }

    // MARK: - Transcript

    private var statusText: String {
        switch odysseus.status {
        case .idle: return "STANDBY"
        case .listening: return "LISTENING…"
        case .thinking: return "PROCESSING…"
        case .speaking: return "RESPONDING…"
        }
    }

    private var subtitlesBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            if odysseus.status == .listening {
                subtitleLine(prefix: ">", text: odysseus.liveTranscript.isEmpty ? "…" : odysseus.liveTranscript, color: .white)
            } else if let last = lastUserMessage {
                subtitleLine(prefix: ">", text: last.content, color: .white)
            }

            if let reply = lastAssistantMessage, odysseus.status != .listening || !odysseus.liveTranscript.isEmpty {
                subtitleLine(prefix: "ODY", text: reply.content, color: Theme.reactorCore)
            }

            if let statusMessage = odysseus.statusMessage {
                subtitleLine(prefix: "!", text: statusMessage, color: Color(hex: "FF6B6B"))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
        .overlay(RoundedRectangle(cornerRadius: 6).stroke(Theme.reactorGlow.opacity(0.5), lineWidth: 1))
    }

    private func subtitleLine(prefix: String, text: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(prefix)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .foregroundStyle(Theme.dimText)
                .frame(width: 36, alignment: .leading)
            Text(text)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var micStatusLine: some View {
        HStack {
            Image(systemName: odysseus.status == .listening ? "mic.fill" : "mic")
                .font(.caption2)
                .foregroundStyle(odysseus.status == .listening ? Theme.terminalGreen : Theme.dimText)
            Text(micStatusText)
                .font(.system(size: 9, design: .monospaced))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            Spacer()
        }
    }

    private var micStatusText: String {
        switch odysseus.status {
        case .idle: return "MIC — TAP TO ACTIVATE"
        case .listening: return "MIC — LISTENING"
        case .thinking: return "MIC — OFF · PROCESSING"
        case .speaking: return "MIC — OFF · RESPONDING"
        }
    }

    // MARK: - Timer

    private var elapsedString: String {
        String(format: "%02d:%02d", elapsed / 60, elapsed % 60)
    }

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in elapsed += 1 }
        }
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
}

#Preview {
    OdysseusTerminalView()
        .environmentObject(OdysseusController.shared)
        .modelContainer(for: [ChatMessage.self, ChatSession.self, Assignment.self, ProjectTask.self, MemoryEntry.self], inMemory: true)
}

//
//  JarvisTerminalView.swift
//  ArshHabitTracker
//
//  Full-screen, voice-only Jarvis takeover. No text input — the arc reactor,
//  a status readout, and a live subtitle box are the entire interface.
//

import SwiftUI
import SwiftData

struct JarvisTerminalView: View {
    @EnvironmentObject private var jarvis: JarvisController
    @Query(sort: \ChatMessage.createdAt, order: .reverse) private var recentMessages: [ChatMessage]

    private var lastUserMessage: ChatMessage? { recentMessages.first { $0.role == "user" } }
    private var lastAssistantMessage: ChatMessage? { recentMessages.first { $0.role == "assistant" } }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                header

                Spacer()

                ArcReactorView(size: 220, isActive: jarvis.status != .idle)

                Text(statusText)
                    .font(.system(.headline, design: .monospaced))
                    .tracking(2)
                    .foregroundStyle(Theme.reactorCore)
                    .padding(.top, 20)

                Spacer()

                subtitlesBox
                    .padding(.horizontal, 20)
                    .padding(.bottom, 24)
            }
        }
        .onAppear { jarvis.expand() }
    }

    private var statusText: String {
        switch jarvis.status {
        case .idle: return "STANDBY"
        case .listening: return "LISTENING…"
        case .thinking: return "PROCESSING…"
        case .speaking: return "RESPONDING…"
        }
    }

    private var header: some View {
        HStack {
            Button {
                jarvis.collapse()
            } label: {
                Image(systemName: "chevron.down.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Theme.reactorCore.opacity(0.85))
            }

            Spacer()

            Text("J.A.R.V.I.S")
                .font(.system(.caption, design: .monospaced).weight(.bold))
                .tracking(4)
                .foregroundStyle(Theme.reactorCore)

            Spacer()

            Button {
                jarvis.deactivate()
            } label: {
                Image(systemName: "power.circle.fill")
                    .font(.title2)
                    .foregroundStyle(Color(hex: "FF6B6B").opacity(0.85))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    private var subtitlesBox: some View {
        VStack(alignment: .leading, spacing: 10) {
            if jarvis.status == .listening {
                subtitleLine(prefix: "YOU", text: jarvis.liveTranscript.isEmpty ? "…" : jarvis.liveTranscript, color: .white)
            } else if let last = lastUserMessage {
                subtitleLine(prefix: "YOU", text: last.content, color: .white)
            }

            if let reply = lastAssistantMessage, jarvis.status != .listening || !jarvis.liveTranscript.isEmpty {
                subtitleLine(prefix: "JARVIS", text: reply.content, color: Theme.reactorCore)
            }

            if let statusMessage = jarvis.statusMessage {
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
                .frame(width: 52, alignment: .leading)
            Text(text)
                .font(.system(.subheadline, design: .monospaced))
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    JarvisTerminalView()
        .environmentObject(JarvisController.shared)
        .modelContainer(for: [ChatMessage.self], inMemory: true)
}

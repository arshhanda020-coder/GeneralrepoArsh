//
//  ChatBubble.swift
//  Odysseus
//
//  Shared chat bubble + Markdown rendering — originally Copilot-only, now
//  used by every AI chat surface (Copilot, each section's Assistant) so
//  they all get the same image display, code-block rendering, and
//  copy/retry/delete actions instead of Copilot being the only polished one.
//

import SwiftUI

struct ChatBubble: View {
    let message: ChatMessage
    /// True only for the last assistant message while it's actively
    /// streaming — draws a blinking cursor at the tail of the text.
    let isStreaming: Bool
    let onCopy: () -> Void
    let onDelete: () -> Void
    let onRetry: (() -> Void)?

    @State private var cursorVisible = true
    private var isUser: Bool { message.role == "user" }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            VStack(alignment: .leading, spacing: 6) {
                if let imageData = message.imageData, let uiImage = PlatformImage(data: imageData) {
                    Image(platformImage: uiImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 160)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    MarkdownContent(text: message.content)
                    if isStreaming {
                        Text("▍")
                            .font(.subheadline)
                            .foregroundStyle(Theme.dimText)
                            .opacity(cursorVisible ? 1 : 0)
                            .onAppear {
                                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                                    cursorVisible = false
                                }
                            }
                    }
                }
            }
            .padding(10)
            .background(isUser ? Theme.accent.opacity(0.25) : Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.cardBorder, lineWidth: 1))
            .contextMenu {
                if !message.content.isEmpty {
                    Button {
                        onCopy()
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                }
                if let onRetry {
                    Button {
                        onRetry()
                    } label: {
                        Label("Retry", systemImage: "arrow.clockwise")
                    }
                }
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

/// Lightweight Markdown rendering for chat replies: fenced ```code``` blocks
/// get their own monospaced panel, everything else renders through
/// AttributedString's inline Markdown parsing (bold/italic/links/inline
/// code) without pulling in a third-party renderer for a chat bubble.
struct MarkdownContent: View {
    let text: String

    var body: some View {
        let segments = Self.segments(for: text)
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                switch segment {
                case .text(let body):
                    if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(Self.inline(body))
                            .font(.subheadline)
                            .foregroundStyle(Theme.primaryText)
                    }
                case .code(let code, let language):
                    VStack(alignment: .leading, spacing: 4) {
                        if let language, !language.isEmpty {
                            Text(language.uppercased())
                                .font(.system(.caption2, design: .monospaced).weight(.bold))
                                .tracking(0.5)
                                .foregroundStyle(Theme.dimText)
                        }
                        Text(code)
                            .font(.system(.caption, design: .monospaced))
                            .foregroundStyle(Theme.primaryText)
                            .textSelection(.enabled)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Theme.background.opacity(0.6))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private enum Segment {
        case text(String)
        case code(String, String?)
    }

    private static func segments(for text: String) -> [Segment] {
        guard text.contains("```") else { return [.text(text)] }

        var result: [Segment] = []
        var remaining = Substring(text)
        while let fenceRange = remaining.range(of: "```") {
            let before = String(remaining[..<fenceRange.lowerBound])
            if !before.isEmpty { result.append(.text(before)) }

            let afterOpenFence = remaining[fenceRange.upperBound...]
            guard let closeRange = afterOpenFence.range(of: "```") else {
                // Unterminated fence (still streaming in) — show what's there so far as code.
                let block = String(afterOpenFence)
                let firstLineEnd = block.firstIndex(of: "\n") ?? block.endIndex
                let language = String(block[..<firstLineEnd]).trimmingCharacters(in: .whitespaces)
                let code = firstLineEnd == block.endIndex ? "" : String(block[block.index(after: firstLineEnd)...])
                result.append(.code(code, language.isEmpty ? nil : language))
                remaining = Substring("")
                break
            }

            let block = afterOpenFence[..<closeRange.lowerBound]
            let firstLineEnd = block.firstIndex(of: "\n") ?? block.endIndex
            let language = String(block[..<firstLineEnd]).trimmingCharacters(in: .whitespaces)
            let code = firstLineEnd == block.endIndex ? "" : String(block[block.index(after: firstLineEnd)...])
            result.append(.code(
                code.trimmingCharacters(in: .newlines),
                language.isEmpty ? nil : language
            ))
            remaining = afterOpenFence[closeRange.upperBound...]
        }
        if !remaining.isEmpty { result.append(.text(String(remaining))) }
        return result
    }

    private static func inline(_ text: String) -> AttributedString {
        (try? AttributedString(
            markdown: text,
            options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        )) ?? AttributedString(text)
    }
}

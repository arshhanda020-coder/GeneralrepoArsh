//
//  AIToolItemDetailView.swift
//  Odysseus
//
//  Detail screen for one AI Tools item (News, Innovation, or a saved repo) —
//  open the link, star it, ask AI a question about it, or (Innovation/saved
//  repos) send it into Copilot to actually build.
//

import SwiftUI

struct AIToolItemDetailView: View {
    let item: AIToolItem

    @State private var safariURL: IdentifiableURL?
    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var askError: String?
    @State private var buildPrompt: IdentifiableString?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                linkSection
                if item.category != .news {
                    buildSection
                }
                inquirySection
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("AI Tools")
        .inlineNavigationTitle()
        .sheet(item: $safariURL) { wrapped in
            SafariView(url: wrapped.url)
        }
        .sheet(item: $buildPrompt) { wrapped in
            BuildWithCopilotSheet(prompt: wrapped.value)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.source.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.3)
                    .foregroundStyle(MindMapSection.aiIntegration.accentColor)
                if item.category == .savedRepo {
                    Text("SAVED REPO")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(Theme.terminalGreen)
                }
                Spacer()
                Button {
                    item.isStarred.toggle()
                } label: {
                    Image(systemName: item.isStarred ? "star.fill" : "star")
                        .foregroundStyle(item.isStarred ? Theme.terminalAmber : Theme.dimText)
                }
                .buttonStyle(.plain)
            }
            Text(item.title)
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
            if let snippet = item.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.subheadline)
                    .foregroundStyle(Theme.dimText)
            }
            if item.category == .savedRepo, let directions = item.installDirections, !directions.isEmpty {
                Divider().overlay(Theme.cardBorder)
                Text("INSTALL DIRECTIONS")
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.dimText)
                Text(directions)
                    .font(.caption)
                    .foregroundStyle(Theme.primaryText)
            }
        }
    }

    private var linkSection: some View {
        Button {
            if let url = URL(string: item.link) {
                safariURL = IdentifiableURL(url: url)
            }
        } label: {
            Label("Open Link", systemImage: "safari")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .tint(MindMapSection.aiIntegration.accentColor)
    }

    private var buildSection: some View {
        Button {
            buildPrompt = IdentifiableString(value: buildPromptText)
        } label: {
            Label("Build this with Copilot", systemImage: "hammer.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .tint(MindMapSection.aiIntegration.accentColor)
    }

    private var inquirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INQUIRIES")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(alignment: .leading, spacing: 10) {
                TextField("Ask AI something about this", text: $question, axis: .vertical)
                    .lineLimit(1...4)
                    .onSubmit {
                        guard !isAsking, !question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                        ask()
                    }

                Button {
                    ask()
                } label: {
                    Label(isAsking ? "Thinking…" : "Ask", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(isAsking || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let askError {
                    Text(askError).font(.caption).foregroundStyle(Color(hex: "C0605C"))
                }
                if let answer {
                    Divider().overlay(Theme.cardBorder)
                    Text(answer).font(.caption).foregroundStyle(Theme.primaryText)
                }
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
        }
    }

    private var buildPromptText: String {
        if item.category == .savedRepo, let directions = item.installDirections {
            return "I saved this GitHub repo: \(item.title) (\(item.link)).\n\n\(item.snippet ?? "")\n\nInstall directions:\n\(directions)\n\nHelp me actually get this working — walk me through it step by step."
        }
        return "I found this: \"\(item.title)\" (\(item.link)).\n\(item.snippet ?? "")\n\nHelp me figure out how to build or integrate something like this into my app. Give me a concrete step-by-step plan."
    }

    private func ask() {
        isAsking = true
        askError = nil
        let prompt = """
        An item from AI Tools: "\(item.title)" from \(item.source) (\(item.category == .news ? "news article" : "community find")).
        Snippet: \(item.snippet ?? "none")
        Link: \(item.link)
        Question: \(question)
        """
        Task {
            do {
                answer = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: nil,
                    systemPrompt: "You are a sharp, concise AI/tech analyst. Answer the user's question using the title/snippet given — note plainly if you'd need the full page to be certain."
                )
            } catch {
                askError = error.localizedDescription
            }
            isAsking = false
        }
    }
}

private struct IdentifiableString: Identifiable {
    let id = UUID()
    let value: String
}

#Preview {
    NavigationStack {
        AIToolItemDetailView(item: AIToolItem(id: "1", title: "Sample", link: "https://example.com", source: "Example", publishedAt: .now, snippet: "A snippet.", category: .innovation))
    }
}

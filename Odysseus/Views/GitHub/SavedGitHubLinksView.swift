//
//  SavedGitHubLinksView.swift
//  Odysseus
//
//  Paste a github.com link — tool stacks, agentic workflows, anything found
//  in the wild — and AI writes a short overview of what it actually is, so
//  it's more than a bare URL when you come back to it later.
//

import SwiftUI
import SwiftData

struct SavedGitHubLinksView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \SavedGitHubLink.addedAt, order: .reverse) private var links: [SavedGitHubLink]

    @State private var newURL = ""
    @State private var isAdding = false
    @State private var addError: String?
    @State private var safariURL: IdentifiableURL?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Paste a github.com link", text: $newURL)
                    .platformAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .platformKeyboardType(.url)
                    .padding(10)
                    .glassPanel(cornerRadius: 8)
                    .onSubmit(addLink)
                Button(action: addLink) {
                    if isAdding {
                        ProgressView().tint(Theme.dimText)
                    } else {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundStyle(newURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dimText : MindMapSection.github.accentColor)
                    }
                }
                .buttonStyle(.plain)
                .disabled(isAdding || newURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if let addError {
                Text(addError).font(.caption).foregroundStyle(Theme.negative)
            }

            if links.isEmpty {
                Text("Nothing saved yet. Paste a link to a repo, tool stack, or agentic workflow you want to remember — AI will summarize what it is.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(links.enumerated()), id: \.element.id) { index, link in
                        if index > 0 {
                            Divider().overlay(Theme.cardBorder)
                        }
                        linkRow(link)
                    }
                }
                .glassPanel(cornerRadius: 10)
            }
        }
        .sheet(item: $safariURL) { wrapped in
            SafariView(url: wrapped.url)
        }
    }

    private func linkRow(_ link: SavedGitHubLink) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(link.repoName ?? link.urlString)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(1)
                Spacer()
                Button {
                    modelContext.delete(link)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Theme.dimText)
                }
                .buttonStyle(.plain)
            }
            if let overview = link.overview, !overview.isEmpty {
                Text(overview)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
            } else {
                Text("Generating overview…")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                    .italic()
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture {
            if let url = URL(string: link.urlString) {
                safariURL = IdentifiableURL(url: url)
            }
        }
    }

    private func addLink() {
        let trimmed = newURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        isAdding = true
        addError = nil

        Task {
            do {
                let info = try await GitHubService.shared.fetchPublicRepoInfo(forURL: trimmed)
                let link = SavedGitHubLink(urlString: trimmed, repoName: info.fullName)
                modelContext.insert(link)
                newURL = ""
                isAdding = false
                await generateOverview(for: link, info: info)
            } catch {
                addError = error.localizedDescription
                isAdding = false
            }
        }
    }

    private func generateOverview(for link: SavedGitHubLink, info: GitHubService.PublicRepoInfo) async {
        let prompt = """
        For this GitHub repository, write EXACTLY this format, nothing else, no markdown:
        OVERVIEW: <2-3 sentence overview — what it does, what it's useful for, who'd want it (e.g. an agentic workflow tool, a specific framework)>
        INSTALL: <step-by-step directions to install/use this as a Claude Code skill or tool in a project — concrete shell commands where relevant (e.g. git clone, where to place it, how to reference it from Claude Code). If it isn't something that installs as a Claude Code skill, give the best real setup steps instead.>
        Repo: \(info.fullName)
        Description: \(info.description ?? "none given")
        Language: \(info.language ?? "unspecified")
        Topics: \((info.topics ?? []).joined(separator: ", "))
        Stars: \(info.stargazersCount)
        URL: \(link.urlString)
        """
        do {
            let response = try await AISettings.currentService.draft(prompt: prompt)
            let (overview, install) = Self.parseOverview(response, fallback: info.description ?? "No overview available.")
            link.overview = overview
            insertAIToolItem(for: link, overview: overview, installDirections: install)
        } catch {
            let fallback = info.description ?? "No overview available."
            link.overview = fallback
            insertAIToolItem(for: link, overview: fallback, installDirections: nil)
        }
    }

    private static func parseOverview(_ text: String, fallback: String) -> (overview: String, install: String?) {
        guard let overviewRange = text.range(of: "OVERVIEW:", options: .caseInsensitive) else {
            return (text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : text, nil)
        }
        let afterOverview = text[overviewRange.upperBound...]
        if let installRange = afterOverview.range(of: "INSTALL:", options: .caseInsensitive) {
            let overview = afterOverview[..<installRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            let install = afterOverview[installRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            return (overview.isEmpty ? fallback : overview, install.isEmpty ? nil : install)
        }
        let overview = afterOverview.trimmingCharacters(in: .whitespacesAndNewlines)
        return (overview.isEmpty ? fallback : overview, nil)
    }

    /// Every saved link also shows up in AI Tools (Innovation) with its
    /// overview and Claude Code install directions, per the request that
    /// saving a link should surface it there too, not just in GitHub.
    private func insertAIToolItem(for link: SavedGitHubLink, overview: String, installDirections: String?) {
        let dedupeID = "savedRepo::\(link.id)"
        let item = AIToolItem(
            id: dedupeID,
            title: link.repoName ?? link.urlString,
            link: link.urlString,
            source: "GitHub",
            publishedAt: link.addedAt,
            snippet: overview,
            category: .savedRepo,
            installDirections: installDirections
        )
        modelContext.insert(item)
    }
}

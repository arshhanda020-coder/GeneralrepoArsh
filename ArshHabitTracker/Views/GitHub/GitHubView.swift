//
//  GitHubView.swift
//  ArshHabitTracker
//

import SwiftUI

struct GitHubView: View {
    @State private var repos: [GitHubService.Repo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var safariURL: IdentifiableURL?
    @State private var hasToken = KeychainService.shared.loadGitHubToken() != nil

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if !hasToken {
                    connectPrompt
                } else if isLoading && repos.isEmpty {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 60)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(Color(hex: "FF6B6B"))
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else if repos.isEmpty {
                    Text("No repositories found.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                } else {
                    reposList
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("GitHub")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingSettings = true
                } label: {
                    Image(systemName: "gearshape")
                }
            }
        }
        .refreshable { await load() }
        .task {
            hasToken = KeychainService.shared.loadGitHubToken() != nil
            if hasToken { await load() }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            hasToken = KeychainService.shared.loadGitHubToken() != nil
            if hasToken { Task { await load() } }
        }) {
            GitHubSettingsSheet()
        }
        .sheet(item: $safariURL) { wrapped in
            SafariView(url: wrapped.url)
        }
    }

    private var connectPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: MindMapSection.github.symbolName)
                .font(.largeTitle)
                .foregroundStyle(MindMapSection.github.accentColor)
            Text("Connect GitHub so Copilot can recall your repositories and projects.")
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
            Button("Add personal access token") { showingSettings = true }
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    private var reposList: some View {
        VStack(spacing: 0) {
            ForEach(Array(repos.enumerated()), id: \.element.id) { index, repo in
                if index > 0 {
                    Divider().overlay(Theme.cardBorder)
                }
                Button {
                    if let url = URL(string: repo.htmlURL) {
                        safariURL = IdentifiableURL(url: url)
                    }
                } label: {
                    repoRow(repo)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private func repoRow(_ repo: GitHubService.Repo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(repo.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                if repo.isPrivate {
                    Image(systemName: "lock.fill")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                }
                Spacer()
                if let language = repo.language {
                    Text(language)
                        .font(.caption2)
                        .foregroundStyle(MindMapSection.github.accentColor)
                }
            }
            if let description = repo.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(2)
            }
            HStack(spacing: 4) {
                Image(systemName: "star.fill").font(.caption2)
                Text("\(repo.stargazersCount)").font(.caption2.monospacedDigit())
            }
            .foregroundStyle(Theme.dimText)
        }
        .padding(10)
        .contentShape(Rectangle())
    }

    private func load() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            repos = try await GitHubService.shared.fetchRepos()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

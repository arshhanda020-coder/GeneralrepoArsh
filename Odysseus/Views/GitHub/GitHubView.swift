//
//  GitHubView.swift
//  Odysseus
//

import SwiftUI

struct GitHubView: View {
    private enum Tab: String, CaseIterable, Identifiable {
        case repos = "My Repositories"
        case saved = "Saved Links"
        var id: String { rawValue }
    }

    @State private var repos: [GitHubService.Repo] = []
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showingSettings = false
    @State private var safariURL: IdentifiableURL?
    @State private var accounts: [GitHubAccount] = GitHubAccountStore.accounts
    @State private var activeAccountID: String? = GitHubAccountStore.activeAccountID
    @State private var selectedTab: Tab = .repos

    private var activeAccount: GitHubAccount? { accounts.first { $0.id == activeAccountID } }
    private var hasToken: Bool {
        guard let activeAccountID else { return false }
        return KeychainService.shared.loadGitHubToken(accountID: activeAccountID) != nil
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)

                if selectedTab == .repos, accounts.count > 1 {
                    accountPicker
                }

                if selectedTab == .saved {
                    SavedGitHubLinksView()
                } else if !hasToken {
                    connectPrompt
                } else if isLoading && repos.isEmpty {
                    ProgressView().tint(.white).frame(maxWidth: .infinity).padding(.top, 60)
                } else if let errorMessage {
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(Theme.negative)
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
            refreshAccounts()
            if hasToken { await load() }
        }
        .sheet(isPresented: $showingSettings, onDismiss: {
            refreshAccounts()
            if hasToken { Task { await load() } }
        }) {
            GitHubSettingsSheet()
        }
        .sheet(item: $safariURL) { wrapped in
            SafariView(url: wrapped.url)
        }
    }

    private var accountPicker: some View {
        Menu {
            ForEach(accounts) { account in
                Button {
                    guard account.id != activeAccountID else { return }
                    activeAccountID = account.id
                    GitHubAccountStore.activeAccountID = account.id
                    repos = []
                    Task { await load() }
                } label: {
                    if account.id == activeAccountID {
                        Label(account.name, systemImage: "checkmark")
                    } else {
                        Text(account.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(activeAccount?.name ?? "Select account")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassPanel(cornerRadius: 8)
        }
    }

    private func refreshAccounts() {
        accounts = GitHubAccountStore.accounts
        activeAccountID = GitHubAccountStore.activeAccountID
    }

    private var connectPrompt: some View {
        VStack(spacing: 10) {
            Image(systemName: MindMapSection.github.symbolName)
                .font(.largeTitle)
                .foregroundStyle(MindMapSection.github.accentColor)
            Text(activeAccount.map { "Add a personal access token for \"\($0.name)\" so Copilot can recall its repositories." } ?? "Connect GitHub so Copilot can recall your repositories and projects.")
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
        .glassPanel(cornerRadius: 10)
    }

    private func repoRow(_ repo: GitHubService.Repo) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(repo.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
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
        guard let activeAccountID else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }
        do {
            repos = try await GitHubService.shared.fetchRepos(accountID: activeAccountID)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

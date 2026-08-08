//
//  AIIntegrationView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct AIIntegrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIToolItem.publishedAt, order: .reverse) private var allItems: [AIToolItem]

    @State private var isRefreshing = false
    @State private var statusMessage: String?
    @State private var selectedTab: Tab = .news
    @State private var selectedItem: AIToolItem?
    @State private var showingSavedOnly = false

    private enum Tab: String, CaseIterable, Identifiable {
        case news = "News"
        case innovation = "Innovation"
        var id: String { rawValue }
    }

    private var newsItems: [AIToolItem] { allItems.filter { $0.category == .news } }
    private var innovationItems: [AIToolItem] { allItems.filter { $0.category == .innovation || $0.category == .savedRepo } }
    private var visibleItems: [AIToolItem] {
        let base = selectedTab == .news ? newsItems : innovationItems
        return showingSavedOnly ? base.filter(\.isStarred) : base
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Picker("Section", selection: $selectedTab) {
                    ForEach(Tab.allCases) { tab in
                        Text(tab.rawValue).tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 8)

                Button {
                    showingSavedOnly.toggle()
                } label: {
                    Label("Saved", systemImage: showingSavedOnly ? "star.fill" : "star")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(showingSavedOnly ? Theme.terminalAmber : Theme.card)
                        .foregroundStyle(showingSavedOnly ? .black : Theme.dimText)
                        .clipShape(Capsule())
                        .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: showingSavedOnly ? 0 : 1))
                }
                .buttonStyle(.plain)
                .padding(.bottom, 8)

                if selectedTab == .innovation {
                    Text("Community finds from Reddit and Hacker News — new tools, prompting tricks, and agentic workflows people actually stumbled onto, not press releases.")
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                        .padding(.bottom, 8)
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.caption2)
                        .foregroundStyle(Theme.dimText)
                        .padding(.bottom, 8)
                }

                if visibleItems.isEmpty && isRefreshing {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if visibleItems.isEmpty {
                    Text("Nothing here yet. Pull to refresh.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else {
                    groupedList
                }
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("AI Tools")
        .inlineNavigationTitle()
        .refreshable { await refresh() }
        .task {
            if allItems.isEmpty { await refresh() }
        }
        .navigationDestination(item: $selectedItem) { item in
            AIToolItemDetailView(item: item)
        }
    }

    private var groupedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(visibleItems.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider().overlay(Theme.cardBorder)
                }
                row(item)
            }
        }
        .glassPanel(cornerRadius: 10)
    }

    private func row(_ item: AIToolItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.source.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .foregroundStyle(MindMapSection.aiIntegration.accentColor)
                if item.category == .savedRepo {
                    Text("SAVED REPO")
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(Theme.terminalGreen)
                }
                Spacer()
                Text(relativeTime(item.publishedAt))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
                Button {
                    item.isStarred.toggle()
                } label: {
                    Image(systemName: item.isStarred ? "star.fill" : "star")
                        .foregroundStyle(item.isStarred ? Theme.terminalAmber : Theme.dimText)
                }
                .buttonStyle(.plain)
            }
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
            if let snippet = item.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(3)
            }
        }
        .padding(10)
        .contentShape(Rectangle())
        .onTapGesture { selectedItem = item }
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        async let newsResult = AIToolsService.shared.fetchNews()
        async let innovationResult = AIToolsService.shared.fetchInnovation()
        let (news, innovation) = await (newsResult, innovationResult)

        if news.items.isEmpty && innovation.items.isEmpty {
            statusMessage = allItems.isEmpty
                ? "Couldn't load. Check your connection."
                : "Couldn't refresh — showing cached items."
            return
        }
        statusMessage = (news.hadFailures || innovation.hadFailures) ? "Some sources didn't respond — showing what we have." : nil

        merge(news.items, category: .news)
        let newInnovationTitles = merge(innovation.items, category: .innovation)
        if !newInnovationTitles.isEmpty {
            NotificationManager.shared.notifyNewInnovation(count: newInnovationTitles.count, firstTitle: newInnovationTitles[0])
        }
    }

    /// Returns titles of genuinely new items (not previously seen) so the
    /// caller can decide whether to notify.
    @discardableResult
    private func merge(_ fetched: [FetchedNewsItem], category: AIToolCategory) -> [String] {
        var newTitles: [String] = []
        for entry in fetched {
            let dedupeID = "\(category.rawValue)::\(entry.dedupeKey)"
            if let existing = allItems.first(where: { $0.id == dedupeID }) {
                existing.link = entry.link
                existing.publishedAt = entry.publishedAt
                existing.snippet = entry.snippet
                existing.source = entry.source
                existing.fetchedAt = .now
            } else {
                let newItem = AIToolItem(
                    id: dedupeID,
                    title: entry.title,
                    link: entry.link,
                    source: entry.source,
                    publishedAt: entry.publishedAt,
                    snippet: entry.snippet,
                    category: category
                )
                modelContext.insert(newItem)
                newTitles.append(entry.title)
            }
        }
        let stale = allItems
            .filter { $0.category == category }
            .sorted { $0.publishedAt > $1.publishedAt }
            .dropFirst(100)
        for item in stale {
            modelContext.delete(item)
        }
        return newTitles
    }
}

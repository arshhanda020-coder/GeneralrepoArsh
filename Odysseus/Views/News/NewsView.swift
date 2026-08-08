//
//  NewsView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct NewsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NewsItem.publishedAt, order: .reverse) private var allItems: [NewsItem]

    @State private var selectedTopic: NewsTopic?
    @State private var isRefreshing = false
    @State private var statusMessage: String?
    @State private var selectedItem: NewsItem?
    @State private var isMarketMode = false
    @State private var showingSavedOnly = false

    private var filteredItems: [NewsItem] {
        let base: [NewsItem]
        if let selectedTopic {
            base = allItems.filter { $0.topic == selectedTopic }
        } else {
            var seen = Set<String>()
            var result: [NewsItem] = []
            for item in allItems {
                let key = item.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if seen.insert(key).inserted {
                    result.append(item)
                }
            }
            base = result
        }
        return showingSavedOnly ? base.filter(\.isStarred) : base
    }

    var body: some View {
        VStack(spacing: 0) {
            topicPicker

            if isMarketMode {
                MarketView()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        if let statusMessage {
                            Text(statusMessage)
                                .font(.caption2)
                                .foregroundStyle(Theme.dimText)
                                .padding(.horizontal, 12)
                                .padding(.top, 4)
                                .padding(.bottom, 8)
                        }

                        if filteredItems.isEmpty && isRefreshing {
                            ProgressView()
                                .tint(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else if filteredItems.isEmpty {
                            Text("No headlines yet. Pull to refresh.")
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
                .refreshable { await refresh() }
            }
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle("News")
        .inlineNavigationTitle()
        .task {
            await refresh()
        }
        .onChange(of: selectedTopic) {
            Task { await refresh() }
        }
        .navigationDestination(item: $selectedItem) { item in
            NewsItemDetailView(item: item)
        }
    }

    private var topicPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(title: "All", topic: nil)
                ForEach(NewsTopic.allCases) { topic in
                    chip(title: topic.displayName, topic: topic)
                }
                marketChip
                savedChip
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(Theme.card)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
    }

    private func chip(title: String, topic: NewsTopic?) -> some View {
        let isSelected = !isMarketMode && selectedTopic == topic
        return Text(title)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Theme.accent : Theme.background)
            .foregroundStyle(isSelected ? .black : Theme.dimText)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: isSelected ? 0 : 1))
            .onTapGesture {
                isMarketMode = false
                selectedTopic = topic
            }
    }

    private var marketChip: some View {
        Label("Market", systemImage: "chart.line.uptrend.xyaxis")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isMarketMode ? Theme.accent : Theme.background)
            .foregroundStyle(isMarketMode ? .black : Theme.dimText)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: isMarketMode ? 0 : 1))
            .onTapGesture { isMarketMode = true }
    }

    private var savedChip: some View {
        Label("Saved", systemImage: "star.fill")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(showingSavedOnly ? Theme.terminalAmber : Theme.background)
            .foregroundStyle(showingSavedOnly ? .black : Theme.dimText)
            .clipShape(Capsule())
            .overlay(Capsule().stroke(Theme.cardBorder, lineWidth: showingSavedOnly ? 0 : 1))
            .onTapGesture {
                isMarketMode = false
                showingSavedOnly.toggle()
            }
    }

    private var groupedList: some View {
        VStack(spacing: 12) {
            ForEach(filteredItems) { item in
                NewsRowView(item: item)
                    .onTapGesture { selectedItem = item }
            }
        }
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let topicsToFetch = selectedTopic.map { [$0] } ?? NewsTopic.allCases
        var anySucceeded = false
        var anyFailure = false

        for topic in topicsToFetch {
            let result = await NewsService.shared.fetchAll(topic: topic)
            if !result.items.isEmpty {
                anySucceeded = true
                merge(result.items, topic: topic)
            }
            if result.hadFailures {
                anyFailure = true
            }
        }

        if !anySucceeded {
            statusMessage = filteredItems.isEmpty
                ? "Couldn't load news. Check your connection."
                : "Couldn't refresh — showing cached headlines."
        } else {
            statusMessage = anyFailure ? "Some sources didn't respond — showing what we have." : nil
        }
    }

    private func merge(_ fetched: [FetchedNewsItem], topic: NewsTopic) {
        for entry in fetched {
            let key = "\(topic.rawValue)::\(entry.dedupeKey)"
            if let existing = allItems.first(where: { $0.id == key }) {
                existing.link = entry.link
                existing.publishedAt = entry.publishedAt
                existing.snippet = entry.snippet
                existing.source = entry.source
                existing.fetchedAt = .now
            } else {
                let newItem = NewsItem(
                    id: key,
                    title: entry.title,
                    link: entry.link,
                    source: entry.source,
                    publishedAt: entry.publishedAt,
                    snippet: entry.snippet,
                    topic: topic
                )
                modelContext.insert(newItem)
            }
        }

        let topicItems = allItems.filter { $0.topic == topic }.sorted { $0.publishedAt > $1.publishedAt }
        for stale in topicItems.dropFirst(80) {
            modelContext.delete(stale)
        }
    }
}

#Preview {
    NavigationStack {
        NewsView()
    }
    .modelContainer(for: [NewsItem.self], inMemory: true)
}

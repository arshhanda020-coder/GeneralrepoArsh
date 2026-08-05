//
//  NewsTickerView.swift
//  ArshHabitTracker
//
//  A horizontally-scrolling strip of headline CARDS along the bottom of the
//  home screen — several visible at once, not a single scrolling line.
//  Tapping a card opens that article; tapping the badge opens News.
//  Fetches its own headlines on first appear if nothing's cached yet, with a
//  hard timeout so it can never sit on "Loading…" forever.
//

import SwiftUI
import SwiftData

struct NewsTickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NewsItem.publishedAt, order: .reverse) private var items: [NewsItem]

    @State private var showingNews = false
    @State private var selectedItem: NewsItem?
    @State private var pulse = false
    @State private var isLoading = false
    @State private var loadFailed = false

    private var topItems: [NewsItem] { Array(items.prefix(15)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            liveBadge

            if topItems.isEmpty {
                statusMessage
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(topItems) { item in
                            headlineCard(item)
                        }
                    }
                    .padding(.horizontal, 14)
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(.top, 10)
        .background(
            LinearGradient(colors: [Theme.card, Theme.background], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.accent.opacity(0.35)).frame(height: 1.2)
        }
        .shadow(color: Theme.accent.opacity(0.18), radius: 10, y: -2)
        .navigationDestination(item: $selectedItem) { item in
            NewsItemDetailView(item: item)
        }
        .sheet(isPresented: $showingNews) {
            NavigationStack { NewsView() }
        }
        .task {
            guard items.isEmpty else { return }
            isLoading = true
            loadFailed = false

            let results = await Self.fetchAllTopicsWithTimeout()
            for (topic, fetched) in results {
                merge(fetched, topic: topic)
            }
            isLoading = false
            loadFailed = results.allSatisfy { $0.1.isEmpty }
        }
    }

    private var statusMessage: some View {
        let message: String
        if isLoading {
            message = "Loading headlines…"
        } else if loadFailed {
            message = "Couldn't load headlines — tap to open News and retry."
        } else {
            message = "No headlines yet — tap to open News and refresh."
        }
        return Text(message)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(Theme.dimText)
            .contentShape(Rectangle())
            .onTapGesture { showingNews = true }
    }

    private func headlineCard(_ item: NewsItem) -> some View {
        let color = topicColor(item.topic)
        return Button {
            selectedItem = item
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 5) {
                    Circle().fill(color).frame(width: 6, height: 6)
                    Text(item.source.uppercased())
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .foregroundStyle(color)
                }
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(width: 220, height: 78, alignment: .topLeading)
            .background(Theme.background)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(color.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func topicColor(_ topic: NewsTopic) -> Color {
        switch topic {
        case .finance: return Theme.reactorGlow
        case .accounting: return Theme.nebulaWispC
        case .economics: return Theme.accent
        case .ai: return Theme.nebulaWispB
        }
    }

    /// Bounds the total wait to ~18s no matter what — a slow or hung feed
    /// can no longer leave the ticker stuck on "Loading…" indefinitely.
    private static func fetchAllTopicsWithTimeout() async -> [(NewsTopic, [FetchedNewsItem])] {
        await withTaskGroup(of: [(NewsTopic, [FetchedNewsItem])].self) { group in
            group.addTask {
                await withTaskGroup(of: (NewsTopic, [FetchedNewsItem]).self) { inner in
                    for topic in NewsTopic.allCases {
                        inner.addTask {
                            let result = await NewsService.shared.fetchAll(topic: topic)
                            return (topic, result.items)
                        }
                    }
                    var collected: [(NewsTopic, [FetchedNewsItem])] = []
                    for await pair in inner { collected.append(pair) }
                    return collected
                }
            }
            group.addTask {
                try? await Task.sleep(nanoseconds: 18_000_000_000)
                return []
            }
            guard let first = await group.next() else { return [] }
            group.cancelAll()
            return first
        }
    }

    private func merge(_ fetched: [FetchedNewsItem], topic: NewsTopic) {
        for entry in fetched {
            let key = "\(topic.rawValue)::\(entry.dedupeKey)"
            guard !items.contains(where: { $0.id == key }) else { continue }
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

    private var liveBadge: some View {
        HStack(spacing: 6) {
            Image(systemName: "newspaper.fill")
                .font(.caption)
                .foregroundStyle(Theme.accent)
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
                .opacity(pulse ? 1 : 0.35)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            Text("LIVE HEADLINES")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Theme.accent)
            Spacer()
            Button {
                showingNews = true
            } label: {
                Text("See all")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .onAppear { pulse = true }
    }
}

//
//  NewsTickerView.swift
//  ArshHabitTracker
//
//  A continuously-scrolling strip of the latest headlines along the bottom
//  of the home screen. Tapping it opens the full News tab. Fetches its own
//  headlines on first appear if nothing's cached yet, with a hard timeout so
//  it can never sit on "Loading…" forever, and batches all inserts into one
//  write at the end instead of one per topic — the home screen has heavy
//  animated content (the nebula, hovering nodes), and firing several small
//  SwiftData inserts while that's on screen was causing visible stutter.
//

import SwiftUI
import SwiftData

struct NewsTickerView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NewsItem.publishedAt, order: .reverse) private var items: [NewsItem]

    @State private var offset: CGFloat = 0
    @State private var measuredWidth: CGFloat = 0
    @State private var showingNews = false
    @State private var pulse = false
    @State private var isLoading = false
    @State private var loadFailed = false

    private var styledHeadline: Text {
        let top = Array(items.prefix(12))
        guard !top.isEmpty else {
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
                .foregroundColor(Theme.dimText)
        }
        var result: Text?
        for item in top {
            let segment = Text(Image(systemName: "circle.fill")).font(.system(size: 5)).foregroundColor(Theme.accent)
                + Text("  " + item.source.uppercased() + "  ").font(.system(.subheadline, design: .monospaced).weight(.bold)).foregroundColor(Theme.accent)
                + Text(item.title).font(.subheadline.weight(.medium)).foregroundColor(Theme.dimText)
            let separator = Text("        ★        ").font(.subheadline).foregroundColor(Theme.accent.opacity(0.4))
            result = result.map { $0 + separator + segment } ?? segment
        }
        return result ?? Text("")
    }

    var body: some View {
        HStack(spacing: 0) {
            liveBadge

            ZStack {
                HStack(spacing: 70) {
                    tickerText
                    tickerText
                }
                .offset(x: offset)
            }
            .frame(height: 46, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.03),
                        .init(color: .black, location: 0.94),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .padding(.trailing, 14)
        .contentShape(Rectangle())
        .onTapGesture { showingNews = true }
        .background(
            LinearGradient(
                colors: [Theme.card, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Theme.accent.opacity(0.35), lineWidth: 1.2)
        )
        .shadow(color: Theme.accent.opacity(0.18), radius: 10, y: -2)
        .padding(.horizontal, 10)
        .padding(.bottom, 10)
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
                .font(.subheadline)
                .foregroundStyle(Theme.accent)
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 1 : 0.35)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            Text("LIVE")
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .tracking(0.6)
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.accent.opacity(0.1))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.accent.opacity(0.25)).frame(width: 1)
        }
        .onAppear { pulse = true }
    }

    private var tickerText: some View {
        styledHeadline
            .fixedSize()
            .padding(.leading, 14)
            .background(
                GeometryReader { proxy in
                    Color.clear.onAppear {
                        guard measuredWidth == 0 else { return }
                        measuredWidth = proxy.size.width
                        startScrolling()
                    }
                }
            )
    }

    private func startScrolling() {
        guard measuredWidth > 0 else { return }
        offset = 0
        withAnimation(.linear(duration: Double(measuredWidth) / 30).repeatForever(autoreverses: false)) {
            offset = -(measuredWidth + 70)
        }
    }
}

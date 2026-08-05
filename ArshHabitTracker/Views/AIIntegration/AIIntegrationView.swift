//
//  AIIntegrationView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct AIIntegrationView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \AIToolItem.publishedAt, order: .reverse) private var items: [AIToolItem]

    @State private var isRefreshing = false
    @State private var statusMessage: String?
    @State private var safariURL: IdentifiableURL?

    var body: some View {
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

                if items.isEmpty && isRefreshing {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 60)
                } else if items.isEmpty {
                    Text("No AI tools news yet. Pull to refresh.")
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
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await refresh() }
        .task {
            if items.isEmpty { await refresh() }
        }
        .sheet(item: $safariURL) { wrapped in
            SafariView(url: wrapped.url)
        }
    }

    private var groupedList: some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                if index > 0 {
                    Divider().overlay(Theme.cardBorder)
                }
                row(item)
                    .onTapGesture {
                        if let url = URL(string: item.link) {
                            safariURL = IdentifiableURL(url: url)
                        }
                    }
            }
        }
        .background(Theme.card)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
    }

    private func row(_ item: AIToolItem) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.source.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(MindMapSection.aiIntegration.accentColor)
                Spacer()
                Text(relativeTime(item.publishedAt))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
            }
            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
            if let snippet = item.snippet, !snippet.isEmpty {
                Text(snippet)
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                    .lineLimit(2)
            }
        }
        .padding(10)
        .contentShape(Rectangle())
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }

        let result = await AIToolsService.shared.fetchAll()
        if result.items.isEmpty {
            statusMessage = items.isEmpty
                ? "Couldn't load. Check your connection."
                : "Couldn't refresh — showing cached items."
            return
        }
        statusMessage = result.hadFailures ? "Some sources didn't respond — showing what we have." : nil
        merge(result.items)
    }

    private func merge(_ fetched: [FetchedNewsItem]) {
        for entry in fetched {
            if let existing = items.first(where: { $0.id == entry.dedupeKey }) {
                existing.link = entry.link
                existing.publishedAt = entry.publishedAt
                existing.snippet = entry.snippet
                existing.source = entry.source
                existing.fetchedAt = .now
            } else {
                let newItem = AIToolItem(
                    id: entry.dedupeKey,
                    title: entry.title,
                    link: entry.link,
                    source: entry.source,
                    publishedAt: entry.publishedAt,
                    snippet: entry.snippet
                )
                modelContext.insert(newItem)
            }
        }
        let stale = items.sorted { $0.publishedAt > $1.publishedAt }.dropFirst(100)
        for item in stale {
            modelContext.delete(item)
        }
    }
}

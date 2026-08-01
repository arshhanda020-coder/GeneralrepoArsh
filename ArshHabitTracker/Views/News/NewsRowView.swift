//
//  NewsRowView.swift
//  ArshHabitTracker
//

import SwiftUI

struct NewsRowView: View {
    let item: NewsItem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text(item.source.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.3)
                    .foregroundStyle(Theme.accent)
                Spacer()
                Text(relativeTime(item.publishedAt))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(Theme.dimText)
            }

            Text(item.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)

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
}

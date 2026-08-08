//
//  NewsRowView.swift
//  Odysseus
//

import SwiftUI

struct NewsRowView: View {
    let item: NewsItem

    private var topicColor: Color {
        switch item.topic {
        case .finance: return Theme.reactorGlow
        case .accounting: return Theme.nebulaWispC
        case .economics: return Theme.accent
        case .ai: return Theme.nebulaWispB
        }
    }

    private var topicIcon: String {
        switch item.topic {
        case .finance: return "chart.line.uptrend.xyaxis"
        case .accounting: return "doc.text.magnifyingglass"
        case .economics: return "globe.americas.fill"
        case .ai: return "sparkles"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle().fill(topicColor.opacity(0.14))
                Image(systemName: topicIcon)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(topicColor)
            }
            .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 6) {
                    Text(item.source.uppercased())
                        .font(.system(.caption2, design: .monospaced).weight(.bold))
                        .tracking(0.4)
                        .foregroundStyle(topicColor)
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
                    .font(.headline)
                    .foregroundStyle(Theme.primaryText)
                    .fixedSize(horizontal: false, vertical: true)

                if let snippet = item.snippet, !snippet.isEmpty {
                    Text(snippet)
                        .font(.subheadline)
                        .foregroundStyle(Theme.dimText)
                        .lineLimit(3)
                }
            }
        }
        .padding(14)
        .glassPanel(cornerRadius: 14, borderColor: topicColor.opacity(0.22))
        .shadow(color: topicColor.opacity(0.08), radius: 8, y: 3)
        .contentShape(Rectangle())
    }

    private func relativeTime(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: .now)
    }
}

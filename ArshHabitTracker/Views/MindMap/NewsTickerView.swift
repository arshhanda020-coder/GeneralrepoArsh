//
//  NewsTickerView.swift
//  ArshHabitTracker
//
//  A continuously-scrolling strip of the latest headlines along the bottom
//  of the home screen. Tapping it opens the full News tab.
//

import SwiftUI
import SwiftData

struct NewsTickerView: View {
    @Query(sort: \NewsItem.publishedAt, order: .reverse) private var items: [NewsItem]

    @State private var offset: CGFloat = 0
    @State private var measuredWidth: CGFloat = 0
    @State private var showingNews = false
    @State private var pulse = false

    private var styledHeadline: Text {
        let top = Array(items.prefix(12))
        guard !top.isEmpty else {
            return Text("No headlines yet — tap to open News and refresh.")
                .font(.caption2.weight(.medium))
                .foregroundColor(Theme.dimText)
        }
        var result: Text?
        for item in top {
            let segment = Text(Image(systemName: "circle.fill")).font(.system(size: 4)).foregroundColor(Theme.accent)
                + Text("  " + item.source.uppercased() + "  ").font(.system(.caption2, design: .monospaced).weight(.bold)).foregroundColor(Theme.accent)
                + Text(item.title).font(.caption2.weight(.medium)).foregroundColor(Theme.dimText)
            let separator = Text("        ★        ").font(.caption2).foregroundColor(Theme.accent.opacity(0.4))
            result = result.map { $0 + separator + segment } ?? segment
        }
        return result ?? Text("")
    }

    var body: some View {
        HStack(spacing: 0) {
            liveBadge

            ZStack {
                HStack(spacing: 60) {
                    tickerText
                    tickerText
                }
                .offset(x: offset)
            }
            .frame(height: 34, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .clipped()
            .mask(
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: 0),
                        .init(color: .black, location: 0.04),
                        .init(color: .black, location: 0.92),
                        .init(color: .clear, location: 1),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
        }
        .padding(.trailing, 12)
        .contentShape(Rectangle())
        .onTapGesture { showingNews = true }
        .background(
            LinearGradient(
                colors: [Theme.card, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Theme.accent.opacity(0.3), lineWidth: 1)
        )
        .shadow(color: Theme.accent.opacity(0.15), radius: 8, y: -2)
        .padding(.horizontal, 10)
        .padding(.bottom, 8)
        .sheet(isPresented: $showingNews) {
            NavigationStack { NewsView() }
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Image(systemName: "newspaper.fill")
                .font(.caption2)
                .foregroundStyle(Theme.accent)
            Circle()
                .fill(Theme.accent)
                .frame(width: 5, height: 5)
                .opacity(pulse ? 1 : 0.35)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            Text("LIVE")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.accent.opacity(0.1))
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.accent.opacity(0.25)).frame(width: 1)
        }
        .onAppear { pulse = true }
    }

    private var tickerText: some View {
        styledHeadline
            .fixedSize()
            .padding(.leading, 12)
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
            offset = -(measuredWidth + 60)
        }
    }
}

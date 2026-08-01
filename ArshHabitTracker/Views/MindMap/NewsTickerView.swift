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

    private var headlineText: String {
        let top = Array(items.prefix(12))
        guard !top.isEmpty else { return "No headlines yet — tap to open News and refresh." }
        return top.map { "\($0.source.uppercased()): \($0.title)" }.joined(separator: "        •        ")
    }

    var body: some View {
        HStack(spacing: 60) {
            tickerText
            tickerText
        }
        .offset(x: offset)
        .frame(height: 26, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .clipped()
        .contentShape(Rectangle())
        .onTapGesture { showingNews = true }
        .background(Theme.card)
        .overlay(alignment: .top) {
            Rectangle().fill(Theme.cardBorder).frame(height: 1)
        }
        .sheet(isPresented: $showingNews) {
            NavigationStack { NewsView() }
        }
    }

    private var tickerText: some View {
        Text(headlineText)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.dimText)
            .fixedSize()
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

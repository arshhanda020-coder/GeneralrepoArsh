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

    private var headlineText: String {
        let top = Array(items.prefix(12))
        guard !top.isEmpty else { return "No headlines yet — tap to open News and refresh." }
        return top.map { "\($0.source.uppercased())  —  \($0.title)" }.joined(separator: "        •        ")
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
            .frame(height: 30, alignment: .leading)
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
        .contentShape(Rectangle())
        .onTapGesture { showingNews = true }
        .background(
            LinearGradient(
                colors: [Theme.card, Theme.background],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Theme.accent.opacity(0.35))
                .frame(height: 1)
        }
        .sheet(isPresented: $showingNews) {
            NavigationStack { NewsView() }
        }
    }

    private var liveBadge: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(Theme.accent)
                .frame(width: 6, height: 6)
                .opacity(pulse ? 1 : 0.4)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
            Text("NEWS")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.accent)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Theme.card)
        .overlay(alignment: .trailing) {
            Rectangle().fill(Theme.cardBorder).frame(width: 1)
        }
        .onAppear { pulse = true }
    }

    private var tickerText: some View {
        Text(headlineText)
            .font(.caption2.weight(.medium))
            .foregroundStyle(Theme.dimText)
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

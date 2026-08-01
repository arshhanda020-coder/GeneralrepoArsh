//
//  DailyQuoteView.swift
//  ArshHabitTracker
//
//  One new AI-written quote per calendar day, cached so it doesn't regenerate
//  (and re-bill an API call) on every app open.
//

import SwiftUI

struct DailyQuoteView: View {
    @State private var quote: String = DailyQuoteStore.todaysCachedQuote ?? ""

    var body: some View {
        Group {
            if !quote.isEmpty {
                Text("\u{201C}\(quote)\u{201D}")
                    .font(.caption.italic())
                    .foregroundStyle(Theme.dimText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .transition(.opacity)
            }
        }
        .task { await loadIfNeeded() }
    }

    private func loadIfNeeded() async {
        if let cached = DailyQuoteStore.todaysCachedQuote {
            quote = cached
            return
        }
        guard AISettings.hasActiveKey else { return }
        do {
            let text = try await AISettings.currentService.draft(prompt: """
            Write ONE short, original, motivating quote — one sentence, no attribution, no quotation marks — \
            for someone juggling school, habits, projects, and personal growth. Return only the quote text.
            """)
            let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return }
            DailyQuoteStore.cache(cleaned)
            withAnimation { quote = cleaned }
        } catch {
            // Decorative only — silently skip if generation fails.
        }
    }
}

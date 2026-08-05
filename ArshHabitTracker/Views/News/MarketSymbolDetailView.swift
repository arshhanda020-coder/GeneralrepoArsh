//
//  MarketSymbolDetailView.swift
//  ArshHabitTracker
//
//  Price + an AI-guessed likely cause for the move, plus an Inquiries box —
//  same pattern as NewsItemDetailView. The "cause" is a reasoned guess from
//  general knowledge, not a citation of a specific verified event.
//

import SwiftUI

struct MarketSymbolDetailView: View {
    let symbol: WatchedSymbol
    let quote: MarketQuote?

    @State private var cause: String?
    @State private var isLoadingCause = false
    @State private var causeError: String?

    @State private var question = ""
    @State private var answer: String?
    @State private var isAsking = false
    @State private var askError: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                priceHeader
                causeSection
                inquirySection
            }
            .padding(12)
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(symbol.symbol.uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadCause() }
    }

    private var priceHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let quote {
                Text(String(format: "%.2f", quote.close))
                    .font(.system(.largeTitle, design: .rounded).weight(.heavy))
                    .foregroundStyle(Theme.primaryText)
                HStack(spacing: 4) {
                    Image(systemName: quote.isUp ? "arrow.up.right" : "arrow.down.right")
                    Text(String(format: "%.2f (%.2f%%)", quote.change, quote.changePercent))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(quote.isUp ? Theme.terminalGreen : Color(hex: "C0605C"))
            } else {
                Text("No price loaded yet.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.dimText)
            }
        }
    }

    private var causeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LIKELY CAUSE")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(alignment: .leading, spacing: 6) {
                if isLoadingCause {
                    ProgressView().tint(Theme.dimText)
                } else if let cause {
                    Text(cause).font(.caption).foregroundStyle(Theme.primaryText)
                } else if let causeError {
                    Text(causeError).font(.caption).foregroundStyle(Color(hex: "C0605C"))
                }
                Text("AI's best guess from general knowledge — not a verified citation.")
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private var inquirySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("INQUIRIES")
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)
            VStack(alignment: .leading, spacing: 10) {
                TextField("Ask AI something about this stock", text: $question, axis: .vertical)
                    .lineLimit(1...4)
                Button {
                    ask()
                } label: {
                    Label(isAsking ? "Thinking…" : "Ask", systemImage: "sparkles")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(isAsking || question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if let askError {
                    Text(askError).font(.caption).foregroundStyle(Color(hex: "C0605C"))
                }
                if let answer {
                    Divider().overlay(Theme.cardBorder)
                    Text(answer).font(.caption).foregroundStyle(Theme.primaryText)
                }
            }
            .padding(12)
            .background(Theme.card)
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.cardBorder, lineWidth: 1))
        }
    }

    private func loadCause() async {
        guard let quote else { return }
        isLoadingCause = true
        causeError = nil
        let prompt = """
        \(symbol.symbol.uppercased()) moved \(String(format: "%.2f%%", quote.changePercent)) (from \(quote.previousClose) to \(quote.close)) in its most recent session.
        In 1-2 sentences, give your best-guess likely reason based on general knowledge of this company/asset and typical market drivers. Be clear this is a reasoned guess, not a confirmed fact.
        """
        do {
            cause = try await AISettings.currentService.askAboutImage(
                prompt: prompt,
                imageData: nil,
                systemPrompt: "You are a market analyst giving brief, honest, hedge-appropriate commentary. Never state speculation as fact."
            )
        } catch {
            causeError = error.localizedDescription
        }
        isLoadingCause = false
    }

    private func ask() {
        isAsking = true
        askError = nil
        let quoteContext = quote.map { "Current price \(String(format: "%.2f", $0.close)), moved \(String(format: "%.2f%%", $0.changePercent)) recently." } ?? "No current price loaded."
        let prompt = "Stock/asset: \(symbol.symbol.uppercased()). \(quoteContext)\nQuestion: \(question)"
        Task {
            do {
                answer = try await AISettings.currentService.askAboutImage(
                    prompt: prompt,
                    imageData: nil,
                    systemPrompt: "You are a concise, honest market analyst. Never present speculation as fact — flag uncertainty plainly."
                )
            } catch {
                askError = error.localizedDescription
            }
            isAsking = false
        }
    }
}

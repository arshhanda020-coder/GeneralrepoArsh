//
//  MarketView.swift
//  Odysseus
//
//  Lives inside the News tab (its own chip) rather than a separate section.
//  Price data only — no Apple integration exists here (Apple doesn't expose
//  a public read API for either Apple News or Apple Stocks).
//

import SwiftUI
import SwiftData

struct MarketView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \WatchedSymbol.sortIndex) private var symbols: [WatchedSymbol]

    @State private var newSymbol = ""
    @State private var quotes: [String: MarketQuote] = [:]
    @State private var loadErrors: [String: String] = [:]
    @State private var isRefreshing = false
    @State private var selectedSymbol: WatchedSymbol?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                TextField("Add a ticker (e.g. AAPL, SPY, TSLA)", text: $newSymbol)
                    .platformAutocapitalization(.characters)
                    .autocorrectionDisabled()
                    .padding(10)
                    .glassPanel(cornerRadius: 8)
                    .onSubmit(addSymbol)
                Button(action: addSymbol) {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Theme.dimText : Theme.accent)
                }
                .buttonStyle(.plain)
                .disabled(newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)

            if symbols.isEmpty {
                Text("Add a ticker to track its price here.")
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                    .padding(.horizontal, 12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(symbols.enumerated()), id: \.element.id) { index, symbol in
                        if index > 0 { Divider().overlay(Theme.cardBorder) }
                        symbolRow(symbol)
                    }
                }
                .glassPanel(cornerRadius: 10)
                .padding(.horizontal, 12)
            }

            Spacer()
        }
        .task { await refreshAll() }
        .refreshable { await refreshAll() }
        .navigationDestination(item: $selectedSymbol) { symbol in
            MarketSymbolDetailView(symbol: symbol, quote: quotes[symbol.symbol.uppercased()])
        }
    }

    private func symbolRow(_ symbol: WatchedSymbol) -> some View {
        Button {
            selectedSymbol = symbol
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(symbol.symbol.uppercased())
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.primaryText)
                    if let error = loadErrors[symbol.symbol.uppercased()] {
                        Text(error)
                            .font(.caption2)
                            .foregroundStyle(Theme.dimText)
                    }
                }
                Spacer()
                if let quote = quotes[symbol.symbol.uppercased()] {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(String(format: "%.2f", quote.close))
                            .font(.subheadline.weight(.semibold).monospacedDigit())
                            .foregroundStyle(Theme.primaryText)
                        HStack(spacing: 2) {
                            Image(systemName: quote.isUp ? "arrow.up.right" : "arrow.down.right")
                            Text(String(format: "%.2f%%", abs(quote.changePercent)))
                        }
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(quote.isUp ? Theme.terminalGreen : Color(hex: "C0605C"))
                    }
                } else if isRefreshing {
                    ProgressView().tint(Theme.dimText)
                }
            }
            .padding(10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .overlay(alignment: .trailing) {
            Button {
                modelContext.delete(symbol)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.dimText)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
        }
    }

    private func addSymbol() {
        let trimmed = newSymbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
        guard !trimmed.isEmpty else { return }
        let nextIndex = (symbols.map(\.sortIndex).max() ?? -1) + 1
        modelContext.insert(WatchedSymbol(symbol: trimmed, sortIndex: nextIndex))
        newSymbol = ""
        Task { await refreshAll() }
    }

    private func refreshAll() async {
        isRefreshing = true
        for symbol in symbols {
            let key = symbol.symbol.uppercased()
            do {
                quotes[key] = try await MarketDataService.shared.fetchQuote(symbol: symbol.symbol)
                loadErrors[key] = nil
            } catch {
                loadErrors[key] = error.localizedDescription
            }
        }
        isRefreshing = false
    }
}

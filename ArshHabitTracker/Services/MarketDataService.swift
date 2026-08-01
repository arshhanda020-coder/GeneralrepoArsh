//
//  MarketDataService.swift
//  ArshHabitTracker
//
//  Stooq's daily-history CSV endpoint is free and needs no API key — used
//  the same way NewsService uses raw RSS, just for price data instead of
//  headlines. Not affiliated with Apple Stocks/Apple News — there's no
//  public API for reading either of those into a third-party app.
//

import Foundation

struct MarketQuote: Sendable {
    let symbol: String
    let close: Double
    let previousClose: Double

    var change: Double { close - previousClose }
    var changePercent: Double { previousClose == 0 ? 0 : (change / previousClose) * 100 }
    var isUp: Bool { change >= 0 }
}

actor MarketDataService {
    static let shared = MarketDataService()

    private init() {}

    enum MarketError: LocalizedError {
        case notFound
        var errorDescription: String? { "No data found for that symbol." }
    }

    func fetchQuote(symbol: String) async throws -> MarketQuote {
        guard let url = URL(string: "https://stooq.com/q/d/l/?s=\(normalize(symbol))&i=d") else {
            throw MarketError.notFound
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15
        let (data, _) = try await URLSession.shared.data(for: request)
        guard let text = String(data: data, encoding: .utf8) else { throw MarketError.notFound }

        let rows = text.split(separator: "\n").map { $0.split(separator: ",").map(String.init) }
        let dataRows = Array(rows.dropFirst())
        guard dataRows.count >= 2 else { throw MarketError.notFound }
        let lastTwo = Array(dataRows.suffix(2))
        guard lastTwo[0].count >= 5, lastTwo[1].count >= 5,
              let prevClose = Double(lastTwo[0][4]),
              let close = Double(lastTwo[1][4]) else {
            throw MarketError.notFound
        }
        return MarketQuote(symbol: symbol.uppercased(), close: close, previousClose: prevClose)
    }

    private func normalize(_ symbol: String) -> String {
        let trimmed = symbol.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return trimmed.contains(".") ? trimmed : "\(trimmed).us"
    }
}

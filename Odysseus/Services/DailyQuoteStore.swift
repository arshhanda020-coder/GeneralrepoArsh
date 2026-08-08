//
//  DailyQuoteStore.swift
//  Odysseus
//

import Foundation

nonisolated enum DailyQuoteStore {
    private static let dateKey = "daily_quote_date"
    private static let textKey = "daily_quote_text"

    private static let dayFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static var todaysCachedQuote: String? {
        guard UserDefaults.standard.string(forKey: dateKey) == dayFormatter.string(from: .now) else { return nil }
        return UserDefaults.standard.string(forKey: textKey)
    }

    static func cache(_ quote: String) {
        UserDefaults.standard.set(dayFormatter.string(from: .now), forKey: dateKey)
        UserDefaults.standard.set(quote, forKey: textKey)
    }
}

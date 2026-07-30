//
//  NewsTopic.swift
//  ArshHabitTracker
//

import Foundation

enum NewsTopic: String, Codable, CaseIterable, Identifiable {
    case finance
    case accounting
    case economics
    case ai

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .finance: return "Finance"
        case .accounting: return "Accounting"
        case .economics: return "Economics"
        case .ai: return "AI"
        }
    }

    var feeds: [(url: String, source: String)] {
        switch self {
        case .finance:
            return [
                ("https://www.cnbc.com/id/10000664/device/rss/rss.html", "CNBC"),
                ("https://feeds.marketwatch.com/marketwatch/topstories/", "MarketWatch"),
            ]
        case .accounting:
            return [
                ("https://www.journalofaccountancy.com/feed.xml", "Journal of Accountancy"),
                ("https://www.accountingtoday.com/feed", "Accounting Today"),
            ]
        case .economics:
            return [
                ("https://www.economist.com/finance-and-economics/rss.xml", "The Economist"),
                ("https://feeds.content.dowjones.io/public/rss/RSSEconomy", "Dow Jones"),
            ]
        case .ai:
            return [
                ("https://techcrunch.com/category/artificial-intelligence/feed/", "TechCrunch"),
                ("https://venturebeat.com/category/ai/feed/", "VentureBeat"),
            ]
        }
    }
}

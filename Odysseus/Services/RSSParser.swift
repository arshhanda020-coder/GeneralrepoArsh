//
//  RSSParser.swift
//  Odysseus
//

import Foundation

struct FetchedNewsItem {
    let title: String
    let link: String
    let source: String
    let publishedAt: Date
    let snippet: String?

    var dedupeKey: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Minimal RSS 2.0 parser built on Foundation's XMLParser — no third-party dependencies.
final class RSSParser: NSObject, XMLParserDelegate {
    private var items: [FetchedNewsItem] = []
    private var source = ""

    private var currentElement = ""
    private var isInsideItem = false
    private var currentTitle = ""
    private var currentLink = ""
    private var currentPubDate = ""
    private var currentDescription = ""

    private static let dateFormatters: [DateFormatter] = {
        let patterns = [
            "EEE, dd MMM yyyy HH:mm:ss Z",
            "EEE, dd MMM yyyy HH:mm:ss zzz",
            "yyyy-MM-dd'T'HH:mm:ssZZZZZ",
        ]
        return patterns.map { pattern in
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.dateFormat = pattern
            return formatter
        }
    }()

    func parse(data: Data, source: String) -> [FetchedNewsItem] {
        items = []
        self.source = source
        let parser = XMLParser(data: data)
        parser.delegate = self
        parser.parse()
        return items
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        currentElement = elementName
        if elementName == "item" {
            isInsideItem = true
            currentTitle = ""
            currentLink = ""
            currentPubDate = ""
            currentDescription = ""
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        guard isInsideItem else { return }
        switch currentElement {
        case "title": currentTitle += string
        case "link": currentLink += string
        case "pubDate": currentPubDate += string
        case "description": currentDescription += string
        default: break
        }
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard elementName == "item" else { return }
        let title = currentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let link = currentLink.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty && !link.isEmpty {
            let date = Self.parseDate(currentPubDate) ?? .now
            items.append(
                FetchedNewsItem(
                    title: decodeEntities(title),
                    link: link,
                    source: source,
                    publishedAt: date,
                    snippet: stripHTML(currentDescription)
                )
            )
        }
        isInsideItem = false
    }

    private static func parseDate(_ string: String) -> Date? {
        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        for formatter in dateFormatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        return nil
    }

    private func stripHTML(_ html: String) -> String? {
        let trimmed = html.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        guard let regex = try? NSRegularExpression(pattern: "<[^>]+>") else { return decodeEntities(trimmed) }
        let range = NSRange(trimmed.startIndex..., in: trimmed)
        let stripped = regex.stringByReplacingMatches(in: trimmed, range: range, withTemplate: "")
        let decoded = decodeEntities(stripped).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !decoded.isEmpty else { return nil }
        return String(decoded.prefix(220))
    }

    private func decodeEntities(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#8217;", with: "\u{2019}")
            .replacingOccurrences(of: "&#8216;", with: "\u{2018}")
            .replacingOccurrences(of: "&#8220;", with: "\u{201C}")
            .replacingOccurrences(of: "&#8221;", with: "\u{201D}")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&quot;", with: "\"")
    }
}

//
//  WatchedSymbol.swift
//  Odysseus
//
//  A market ticker the user wants tracked in News > Market.
//

import Foundation
import SwiftData

@Model
final class WatchedSymbol {
    var id: String = UUID().uuidString
    var symbol: String = ""
    var displayName: String?
    var sortIndex: Int = 0
    var createdAt: Date = Date.now

    init(
        id: String = UUID().uuidString,
        symbol: String,
        displayName: String? = nil,
        sortIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.symbol = symbol
        self.displayName = displayName
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}

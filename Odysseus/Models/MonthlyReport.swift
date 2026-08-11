//
//  MonthlyReport.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class MonthlyReport {
    var id: String = UUID().uuidString
    var generatedAt: Date = .now
    var periodStart: Date = .now
    var periodEnd: Date = .now
    var startWeight: Double?
    var endWeight: Double?
    var summaryText: String = ""

    init(
        id: String = UUID().uuidString,
        generatedAt: Date = .now,
        periodStart: Date,
        periodEnd: Date,
        startWeight: Double? = nil,
        endWeight: Double? = nil,
        summaryText: String
    ) {
        self.id = id
        self.generatedAt = generatedAt
        self.periodStart = periodStart
        self.periodEnd = periodEnd
        self.startWeight = startWeight
        self.endWeight = endWeight
        self.summaryText = summaryText
    }
}

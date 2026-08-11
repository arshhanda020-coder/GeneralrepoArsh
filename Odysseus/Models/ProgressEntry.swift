//
//  ProgressEntry.swift
//  Odysseus
//
//  One day's physique check-in — morning photo + weight.
//

import Foundation
import SwiftData

@Model
final class ProgressEntry {
    var id: String = UUID().uuidString
    var date: Date = Date.now
    var weight: Double?
    var photoData: Data?
    var notes: String?
    var createdAt: Date = Date.now

    init(
        id: String = UUID().uuidString,
        date: Date,
        weight: Double? = nil,
        photoData: Data? = nil,
        notes: String? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.date = date
        self.weight = weight
        self.photoData = photoData
        self.notes = notes
        self.createdAt = createdAt
    }
}

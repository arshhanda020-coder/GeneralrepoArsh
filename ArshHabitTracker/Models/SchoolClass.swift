//
//  SchoolClass.swift
//  ArshHabitTracker
//

import Foundation
import SwiftData

@Model
final class SchoolClass {
    var id: String
    var name: String
    var isEnrolled: Bool
    var sortIndex: Int
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Topic.schoolClass)
    var topics: [Topic] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        isEnrolled: Bool = true,
        sortIndex: Int = 0,
        createdAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.isEnrolled = isEnrolled
        self.sortIndex = sortIndex
        self.createdAt = createdAt
    }
}

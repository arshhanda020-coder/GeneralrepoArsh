//
//  SchoolClass.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class SchoolClass {
    var id: String = UUID().uuidString
    var name: String = ""
    var isEnrolled: Bool = true
    var sortIndex: Int = 0
    var createdAt: Date = .now

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

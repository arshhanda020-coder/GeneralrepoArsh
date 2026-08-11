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
    /// Index into `ClassBannerColor.allCases`, or -1 for "not chosen yet" —
    /// falls back to a stable auto-assigned color (see `bannerColor` below)
    /// so every class still gets a distinct Classroom-style banner color
    /// without the user having to pick one.
    var colorIndex: Int = -1

    @Relationship(deleteRule: .cascade, inverse: \Topic.schoolClass)
    var topics: [Topic] = []

    init(
        id: String = UUID().uuidString,
        name: String,
        isEnrolled: Bool = true,
        sortIndex: Int = 0,
        createdAt: Date = .now,
        colorIndex: Int = -1
    ) {
        self.id = id
        self.name = name
        self.isEnrolled = isEnrolled
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.colorIndex = colorIndex
    }
}

extension SchoolClass {
    /// The class's banner color — whatever was explicitly picked, or a
    /// stable auto-assignment hashed from the class's id so it stays put
    /// across relaunches until the user chooses one themselves.
    var bannerColor: ClassBannerColor {
        if colorIndex >= 0, let picked = ClassBannerColor(rawValue: colorIndex) {
            return picked
        }
        return .auto(for: id)
    }
}

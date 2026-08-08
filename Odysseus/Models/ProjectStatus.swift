//
//  ProjectStatus.swift
//  Odysseus
//

import SwiftUI

enum ProjectStatus: String, Codable, CaseIterable, Identifiable {
    case planning
    case building
    case paused
    case shipped

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .planning: return "Planning"
        case .building: return "Building"
        case .paused: return "Paused"
        case .shipped: return "Shipped"
        }
    }

    var color: Color {
        switch self {
        case .planning: return Color(hex: "4F8FA8")
        case .building: return Color(hex: "5FCB8C")
        case .paused: return Color(hex: "7C8A8D")
        case .shipped: return Color(hex: "8A7CA8")
        }
    }
}

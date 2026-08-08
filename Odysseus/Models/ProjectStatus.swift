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
        case .planning: return Color(hex: "38BDF8")
        case .building: return Color(hex: "4ADE80")
        case .paused: return Color(hex: "8A94A3")
        case .shipped: return Color(hex: "A78BFA")
        }
    }
}

//
//  ResearchEntry.swift
//  Odysseus
//

import Foundation
import SwiftData

enum ResearchCategory: String, Codable, CaseIterable, Identifiable {
    case school
    case project
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .school: return "School"
        case .project: return "Project"
        case .other: return "Other"
        }
    }
}

@Model
final class ResearchEntry {
    var id: String = UUID().uuidString
    var topic: String = ""
    var categoryRaw: String = ResearchCategory.other.rawValue
    var content: String = ""
    var createdAt: Date = .now
    var project: Project?
    /// Set when this research auto-created a matching Extracurricular entry
    /// (school-category research), so the two stay linked.
    var linkedExtracurricularID: String?

    var category: ResearchCategory {
        get { ResearchCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    init(
        id: String = UUID().uuidString,
        topic: String,
        category: ResearchCategory,
        content: String,
        createdAt: Date = .now,
        project: Project? = nil,
        linkedExtracurricularID: String? = nil
    ) {
        self.id = id
        self.topic = topic
        self.categoryRaw = category.rawValue
        self.content = content
        self.createdAt = createdAt
        self.project = project
        self.linkedExtracurricularID = linkedExtracurricularID
    }
}

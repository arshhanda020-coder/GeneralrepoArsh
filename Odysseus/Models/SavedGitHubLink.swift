//
//  SavedGitHubLink.swift
//  Odysseus
//
//  A GitHub link worth remembering — a tool stack, an agentic workflow repo,
//  anything found out in the wild — with an AI-written overview of what it
//  actually is, so the link isn't just a bare URL months later.
//

import Foundation
import SwiftData

@Model
final class SavedGitHubLink {
    var id: String = UUID().uuidString
    var urlString: String = ""
    var repoName: String?
    var overview: String?
    var addedAt: Date = Date.now

    init(
        id: String = UUID().uuidString,
        urlString: String,
        repoName: String? = nil,
        overview: String? = nil,
        addedAt: Date = .now
    ) {
        self.id = id
        self.urlString = urlString
        self.repoName = repoName
        self.overview = overview
        self.addedAt = addedAt
    }
}

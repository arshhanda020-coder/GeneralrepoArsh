//
//  TopicMaterial.swift
//  Odysseus
//
//  Raw material for a topic — PDFs, slideshows, or anything else imported
//  from class, plus typed/pasted text. Distinct from Notes (your own
//  writing) and from StudyMaterial (exam-scoped, feeds the AI study plan):
//  this is just a place to keep the source material itself. Test Me also
//  reads it as context so quizzes reflect what's actually in here.
//

import Foundation
import SwiftData

@Model
final class TopicMaterial {
    var id: String
    var topic: Topic?
    /// Typed or pasted text — set when this entry isn't an imported file (or alongside one, as a caption/description).
    var text: String?
    /// Raw bytes of an imported file (PDF, slideshow, doc, image, whatever was picked).
    var fileData: Data?
    var fileName: String?
    var addedAt: Date

    init(
        id: String = UUID().uuidString,
        topic: Topic? = nil,
        text: String? = nil,
        fileData: Data? = nil,
        fileName: String? = nil,
        addedAt: Date = .now
    ) {
        self.id = id
        self.topic = topic
        self.text = text
        self.fileData = fileData
        self.fileName = fileName
        self.addedAt = addedAt
    }

    /// Fall/Spring, derived from when it was added.
    var term: SchoolTerm { SchoolTerm.term(for: addedAt) }
}

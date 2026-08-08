//
//  StudyMaterial.swift
//  Odysseus
//
//  Raw material you feed the March Exam study plan — pasted notes/text
//  and/or a photo of something (a worksheet, a textbook page, a review
//  sheet). The plan generator reads all of it (photos get vision-described
//  first) so the reviews/assignments/tests it paces out are grounded in
//  what you actually gave it, not guesses from the exam name alone.
//

import Foundation
import SwiftData

@Model
final class StudyMaterial {
    var id: String
    var exam: Exam?
    var text: String?
    var photoData: Data?
    var addedAt: Date

    init(
        id: String = UUID().uuidString,
        exam: Exam? = nil,
        text: String? = nil,
        photoData: Data? = nil,
        addedAt: Date = .now
    ) {
        self.id = id
        self.exam = exam
        self.text = text
        self.photoData = photoData
        self.addedAt = addedAt
    }
}

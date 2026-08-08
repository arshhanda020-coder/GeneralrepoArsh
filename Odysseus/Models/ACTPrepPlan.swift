//
//  ACTPrepPlan.swift
//  Odysseus
//

import Foundation
import SwiftData

@Model
final class ACTPrepPlan {
    var id: String
    var exam: Exam?
    var planText: String
    var strengthsWeaknessesText: String?
    var generatedAt: Date

    init(
        id: String = UUID().uuidString,
        exam: Exam? = nil,
        planText: String,
        strengthsWeaknessesText: String? = nil,
        generatedAt: Date = .now
    ) {
        self.id = id
        self.exam = exam
        self.planText = planText
        self.strengthsWeaknessesText = strengthsWeaknessesText
        self.generatedAt = generatedAt
    }
}

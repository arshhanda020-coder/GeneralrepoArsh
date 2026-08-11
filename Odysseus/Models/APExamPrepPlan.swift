//
//  APExamPrepPlan.swift
//  Odysseus
//
//  AP's own prep-plan record — deliberately a separate model from
//  ACTPrepPlan (not reused) since AP prep is its own system: a single 1-5
//  score per exam rather than four sub-sections, so the plan/analysis
//  prompts and shape differ from ACT's.
//

import Foundation
import SwiftData

@Model
final class APExamPrepPlan {
    var id: String = UUID().uuidString
    var exam: Exam?
    var planText: String = ""
    var strengthsWeaknessesText: String?
    var generatedAt: Date = Date.now

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

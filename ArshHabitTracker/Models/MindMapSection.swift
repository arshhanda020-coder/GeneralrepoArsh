//
//  MindMapSection.swift
//  ArshHabitTracker
//

import SwiftUI

enum MindMapSection: String, CaseIterable, Identifiable, Hashable {
    case today
    case skills
    case projects
    case news
    case copilot
    case stats
    case emails
    case aiIntegration
    case github
    case school
    case food
    case workouts
    case calendar
    case extracurriculars

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Today"
        case .skills: return "Skills"
        case .projects: return "Projects"
        case .news: return "News"
        case .copilot: return "Copilot"
        case .stats: return "Stats"
        case .emails: return "Emails"
        case .aiIntegration: return "AI Tools"
        case .github: return "GitHub"
        case .school: return "School"
        case .food: return "Food"
        case .workouts: return "Workouts"
        case .calendar: return "Calendar"
        case .extracurriculars: return "Extracurriculars"
        }
    }

    /// Fits the fixed-width mind-map node — `title` is still what's shown as
    /// the actual screen's navigation title.
    var shortTitle: String {
        self == .extracurriculars ? "Activities" : title
    }

    /// SF Symbols only — no emoji. Keeps the home screen looking like
    /// instrumentation, not a sticker sheet.
    var symbolName: String {
        switch self {
        case .today: return "checkmark.seal"
        case .skills: return "chart.line.uptrend.xyaxis"
        case .projects: return "hammer"
        case .news: return "newspaper"
        case .copilot: return "waveform"
        case .stats: return "chart.bar.xaxis"
        case .emails: return "envelope"
        case .aiIntegration: return "bolt.fill"
        case .github: return "chevron.left.forwardslash.chevron.right"
        case .school: return "graduationcap.fill"
        case .food: return "fork.knife"
        case .workouts: return "figure.run"
        case .calendar: return "calendar"
        case .extracurriculars: return "rosette"
        }
    }

    /// A restrained, closely-related family of muted tones — one design, not
    /// a different saturated color per tab. Copilot/AI Tools share the app's
    /// signature brass accent; everything else sits in quiet steel-blue or
    /// warm taupe, varying just enough to still tell sections apart at a glance.
    var accentHex: String {
        switch self {
        case .today: return "5C7A99"
        case .skills: return "6C8AA6"
        case .projects: return "748CA3"
        case .news: return "8A8368"
        case .copilot: return "C9A227"
        case .stats: return "5F6672"
        case .emails: return "6B7280"
        case .aiIntegration: return "B8935B"
        case .github: return "747C87"
        case .school: return "7D8570"
        case .food: return "9C8F6E"
        case .workouts: return "8E7B5E"
        case .calendar: return "6C8AA6"
        case .extracurriculars: return "A08A5E"
        }
    }

    var accentColor: Color { Color(hex: accentHex) }
}

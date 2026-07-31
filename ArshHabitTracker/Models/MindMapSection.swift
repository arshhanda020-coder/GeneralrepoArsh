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
        }
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
        }
    }

    /// Fully-saturated, high-contrast accents — instrumentation colors, not pastel.
    var accentHex: String {
        switch self {
        case .today: return "2563EB"
        case .skills: return "16A34A"
        case .projects: return "9333EA"
        case .news: return "D97706"
        case .copilot: return "0EA5E9"
        case .stats: return "0369A1"
        case .emails: return "DC2626"
        case .aiIntegration: return "0D9488"
        case .github: return "71717A"
        case .school: return "4F46E5"
        case .food: return "EA580C"
        case .workouts: return "E11D48"
        case .calendar: return "C026D3"
        }
    }

    var accentColor: Color { Color(hex: accentHex) }
}

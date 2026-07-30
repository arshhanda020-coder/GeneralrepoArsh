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
        }
    }

    /// Muted, desaturated accents — instrumentation colors, not pastel.
    var accentHex: String {
        switch self {
        case .today: return "3B82F6"
        case .skills: return "10B981"
        case .projects: return "6366F1"
        case .news: return "B45309"
        case .copilot: return "0EA5E9"
        case .stats: return "0284C7"
        case .emails: return "B91C1C"
        case .aiIntegration: return "0891B2"
        case .github: return "94A3B8"
        }
    }

    var accentColor: Color { Color(hex: accentHex) }
}

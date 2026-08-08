//
//  MindMapSection.swift
//  Odysseus
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
    case health
    case calendar
    case extracurriculars
    case memory
    case research
    case agents
    case claudeCode
    case codex
    case obsidian
    case notes

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
        case .health: return "Health"
        case .calendar: return "Calendar"
        case .extracurriculars: return "Extracurriculars"
        case .memory: return "Memory"
        case .research: return "Research"
        case .agents: return "Subagents"
        case .claudeCode: return "Claude Code"
        case .codex: return "Codex"
        case .obsidian: return "Obsidian Vault"
        case .notes: return "Notes"
        }
    }

    /// Fits the fixed-width mind-map node — `title` is still what's shown as
    /// the actual screen's navigation title.
    var shortTitle: String {
        self == .extracurriculars ? "Activities" : title
    }

    /// Short enough to fit a narrow HUD side-panel row alongside a badge value.
    var hudCode: String {
        switch self {
        case .today: return "TODAY"
        case .skills: return "SKILLS"
        case .projects: return "PROJ"
        case .news: return "NEWS"
        case .copilot: return "COPLT"
        case .stats: return "STATS"
        case .emails: return "MAIL"
        case .aiIntegration: return "AI"
        case .github: return "GIT"
        case .school: return "SCHOOL"
        case .health: return "HEALTH"
        case .calendar: return "CAL"
        case .extracurriculars: return "ACT"
        case .memory: return "MEM"
        case .research: return "RSRCH"
        case .agents: return "AGENT"
        case .claudeCode: return "CLAUDE"
        case .codex: return "CODEX"
        case .obsidian: return "VAULT"
        case .notes: return "NOTES"
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
        case .health: return "heart.fill"
        case .calendar: return "calendar"
        case .extracurriculars: return "rosette"
        case .memory: return "brain"
        case .research: return "magnifyingglass"
        case .agents: return "cpu"
        case .claudeCode: return "terminal"
        case .codex: return "chevron.left.forwardslash.chevron.right"
        case .obsidian: return "brain.head.profile"
        case .notes: return "note.text"
        }
    }

    /// Every section shares the app's one signature accent now, instead of a
    /// different muted hue per tab — closer to how Messages/Settings-style
    /// apps use a single accent everywhere rather than a color-coded tab bar.
    var accentColor: Color { Theme.accent }
}

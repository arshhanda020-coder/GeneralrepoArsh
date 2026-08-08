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
        case .agents: return "Agentic Workflows"
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
        case .agents: return "FLOW"
        case .claudeCode: return "CLAUDE"
        case .codex: return "CODEX"
        case .obsidian: return "VAULT"
        case .notes: return "NOTES"
        }
    }

    /// A small set of flat iOS system colors, one per section's row icon
    /// badge — the same idea as the colored row icons in Settings/Reminders,
    /// which is what actually keeps a 20-row flat list scannable (a single
    /// accent everywhere works for buttons/links, but not for that many
    /// identical rows in a row).
    var builtInAccentHex: String {
        switch self {
        case .today: return "34C759" // green
        case .skills: return "00C7BE" // mint
        case .projects: return "FF9500" // orange
        case .news: return "FF3B30" // red
        case .copilot: return "5856D6" // indigo
        case .stats: return "007AFF" // blue
        case .emails: return "32ADE6" // cyan
        case .aiIntegration: return "AF52DE" // purple
        case .github: return "8E8E93" // gray
        case .school: return "A2845E" // brown
        case .health: return "FF2D55" // pink
        case .calendar: return "FF3B30" // red
        case .extracurriculars: return "FFCC00" // yellow
        case .memory: return "AF52DE" // purple
        case .research: return "30B0C7" // teal
        case .agents: return "5856D6" // indigo
        case .claudeCode: return "FF9500" // orange
        case .codex: return "5856D6" // indigo
        case .obsidian: return "AF52DE" // purple
        case .notes: return "FFCC00" // yellow
        }
    }

    var accentColor: Color { Color(hex: builtInAccentHex) }

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
}

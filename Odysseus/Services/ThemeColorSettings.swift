//
//  ThemeColorSettings.swift
//  Odysseus
//
//  Every color token in the app is overridable from Settings > Appearance.
//  These are the built-in defaults — a premium dark HUD palette: near-
//  black graphite voids, a deep emerald signature accent, cooler blue and
//  quiet olive wisps for depth, and exactly one gold used sparingly for
//  highlights (never as a base color) instead of a saturated hue everywhere.
//  An override in UserDefaults wins when present.
//

import Foundation

enum ThemeToken: String, CaseIterable, Identifiable {
    case background, card, cardBorder, dimText, primaryText
    case accent, terminalGreen, terminalAmber, negative
    case reactorCore, reactorDeep, reactorGlow
    case nebulaWispB, nebulaWispC, reactorAccentB

    var id: String { rawValue }

    var defaultHex: String {
        switch self {
        case .background: return "0B0E10"
        case .card: return "141A1D"
        case .cardBorder: return "232B2E"
        case .dimText: return "7C8A8D"
        case .primaryText: return "F1ECE2"
        case .accent: return "2F8577"
        case .terminalGreen: return "5FCB8C"
        case .terminalAmber: return "C9A227"
        case .negative: return "D9695F"
        case .reactorCore: return "F2F5F4"
        case .reactorDeep: return "060907"
        case .reactorGlow: return "3FA98F"
        case .nebulaWispB: return "4F8FA8"
        case .nebulaWispC: return "8A7C6B"
        case .reactorAccentB: return "C9A227"
        }
    }

    var displayName: String {
        switch self {
        case .background: return "Background"
        case .card: return "Card Surface"
        case .cardBorder: return "Card Border"
        case .dimText: return "Secondary Text"
        case .primaryText: return "Primary Text"
        case .accent: return "Signature Accent"
        case .terminalGreen: return "Success / Done"
        case .terminalAmber: return "Highlight / Amber"
        case .negative: return "Error / Alert"
        case .reactorCore: return "Reactor Core (Pale Mint)"
        case .reactorDeep: return "Reactor Void"
        case .reactorGlow: return "Reactor Arc (Teal)"
        case .nebulaWispB: return "Reactor Arc (Blue)"
        case .nebulaWispC: return "Reactor Arc (Olive)"
        case .reactorAccentB: return "Reactor Arc (Gold)"
        }
    }
}

nonisolated enum ThemeColorSettings {
    private static func key(_ token: ThemeToken) -> String { "theme_color_\(token.rawValue)" }
    private static func sectionKey(_ section: MindMapSection) -> String { "theme_section_color_\(section.rawValue)" }
    static func hex(for token: ThemeToken) -> String {
        UserDefaults.standard.string(forKey: key(token)) ?? token.defaultHex
    }

    static func setHex(_ hex: String, for token: ThemeToken) {
        UserDefaults.standard.set(hex, forKey: key(token))
    }

    static func sectionHex(for section: MindMapSection) -> String {
        UserDefaults.standard.string(forKey: sectionKey(section)) ?? section.builtInAccentHex
    }

    static func setSectionHex(_ hex: String, for section: MindMapSection) {
        UserDefaults.standard.set(hex, forKey: sectionKey(section))
    }

    static func resetAll() {
        for token in ThemeToken.allCases { UserDefaults.standard.removeObject(forKey: key(token)) }
        for section in MindMapSection.allCases { UserDefaults.standard.removeObject(forKey: sectionKey(section)) }
    }
}

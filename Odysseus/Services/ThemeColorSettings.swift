//
//  ThemeColorSettings.swift
//  Odysseus
//
//  Every color token in the app is overridable from Settings > Appearance.
//  These are the built-in defaults — a plain, native-feeling light palette
//  modeled on Notes/iMessage/X: a warm paper background, white cards, near-
//  black text, hairline dividers instead of glowing borders, and iMessage's
//  system blue as the one signature accent used everywhere.
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
        case .background: return "F7F7F5"
        case .card: return "FFFFFF"
        case .cardBorder: return "E5E5EA"
        case .dimText: return "8E8E93"
        case .primaryText: return "1C1C1E"
        case .accent: return "007AFF"
        case .terminalGreen: return "34C759"
        case .terminalAmber: return "FF9500"
        case .negative: return "FF3B30"
        case .reactorCore: return "FFFFFF"
        case .reactorDeep: return "E5E5EA"
        case .reactorGlow: return "007AFF"
        case .nebulaWispB: return "5AC8FA"
        case .nebulaWispC: return "AEAEB2"
        case .reactorAccentB: return "FF9500"
        }
    }

    var displayName: String {
        switch self {
        case .background: return "Background"
        case .card: return "Card Surface"
        case .cardBorder: return "Hairline Divider"
        case .dimText: return "Secondary Text"
        case .primaryText: return "Primary Text"
        case .accent: return "Signature Accent"
        case .terminalGreen: return "Success / Done"
        case .terminalAmber: return "Highlight / Amber"
        case .negative: return "Error / Alert"
        case .reactorCore: return "Assistant Core (White)"
        case .reactorDeep: return "Assistant Void"
        case .reactorGlow: return "Assistant Arc (Blue)"
        case .nebulaWispB: return "Assistant Arc (Light Blue)"
        case .nebulaWispC: return "Assistant Arc (Gray)"
        case .reactorAccentB: return "Assistant Arc (Amber)"
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

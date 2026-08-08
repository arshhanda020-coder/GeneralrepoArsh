//
//  ThemeColorSettings.swift
//  Odysseus
//
//  Every color token in the app is overridable from Settings > Appearance.
//  These are the built-in defaults — a neon-green HUD palette: black voids,
//  glowing green rings/text/borders throughout the reactor and every
//  section panel. An override in UserDefaults wins when present.
//

import Foundation

enum ThemeToken: String, CaseIterable, Identifiable {
    case background, card, cardBorder, dimText, primaryText
    case accent, terminalGreen, terminalAmber
    case reactorCore, reactorDeep, reactorGlow
    case nebulaWispB, nebulaWispC, reactorAccentB

    var id: String { rawValue }

    var defaultHex: String {
        switch self {
        case .background: return "0B0910"
        case .card: return "17131F"
        case .cardBorder: return "2C2438"
        case .dimText: return "9A90AC"
        case .primaryText: return "F3EFFA"
        case .accent: return "B48CE0"
        case .terminalGreen: return "39FF14"
        case .terminalAmber: return "E0B34C"
        case .reactorCore: return "39FF14"
        case .reactorDeep: return "021505"
        case .reactorGlow: return "2BFF88"
        case .nebulaWispB: return "7CFFB2"
        case .nebulaWispC: return "1FAE58"
        case .reactorAccentB: return "39FF14"
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
        case .reactorCore: return "Reactor Core (White-Cyan)"
        case .reactorDeep: return "Reactor Void"
        case .reactorGlow: return "Reactor Arc (Electric Blue)"
        case .nebulaWispB: return "Reactor Arc (Cyan)"
        case .nebulaWispC: return "Reactor Arc (Indigo)"
        case .reactorAccentB: return "Reactor Arc (Magenta)"
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

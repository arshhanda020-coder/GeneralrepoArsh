//
//  ThemeColorSettings.swift
//  ArshHabitTracker
//
//  Every color token in the app is overridable from Settings > Appearance.
//  These are the built-in defaults (dark, purple/magenta nebula palette) —
//  an override in UserDefaults wins when present.
//

import Foundation

enum ThemeToken: String, CaseIterable, Identifiable {
    case background, card, cardBorder, dimText, primaryText
    case accent, terminalGreen, terminalAmber
    case reactorCore, reactorDeep, reactorGlow
    case nebulaWispB, nebulaWispC

    var id: String { rawValue }

    var defaultHex: String {
        switch self {
        case .background: return "0B0910"
        case .card: return "17131F"
        case .cardBorder: return "2C2438"
        case .dimText: return "9A90AC"
        case .primaryText: return "F3EFFA"
        case .accent: return "B48CE0"
        case .terminalGreen: return "6FD6A8"
        case .terminalAmber: return "E0B34C"
        case .reactorCore: return "8EC8F5"
        case .reactorDeep: return "0C0716"
        case .reactorGlow: return "A44FD9"
        case .nebulaWispB: return "E668C4"
        case .nebulaWispC: return "5C6EE8"
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
        case .reactorCore: return "Nebula Core (Blue-White)"
        case .reactorDeep: return "Nebula Void"
        case .reactorGlow: return "Nebula Wisp (Purple)"
        case .nebulaWispB: return "Nebula Wisp (Magenta)"
        case .nebulaWispC: return "Nebula Wisp (Indigo)"
        }
    }
}

nonisolated enum ThemeColorSettings {
    private static func key(_ token: ThemeToken) -> String { "theme_color_\(token.rawValue)" }
    private static func sectionKey(_ section: MindMapSection) -> String { "theme_section_color_\(section.rawValue)" }
    private static func categoryKey(_ category: HabitCategory) -> String { "theme_category_color_\(category.rawValue)" }

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

    static func categoryHex(for category: HabitCategory) -> String {
        UserDefaults.standard.string(forKey: categoryKey(category)) ?? category.builtInAccentHex
    }

    static func setCategoryHex(_ hex: String, for category: HabitCategory) {
        UserDefaults.standard.set(hex, forKey: categoryKey(category))
    }

    static func resetAll() {
        for token in ThemeToken.allCases { UserDefaults.standard.removeObject(forKey: key(token)) }
        for section in MindMapSection.allCases { UserDefaults.standard.removeObject(forKey: sectionKey(section)) }
        for category in HabitCategory.allCases { UserDefaults.standard.removeObject(forKey: categoryKey(category)) }
    }
}

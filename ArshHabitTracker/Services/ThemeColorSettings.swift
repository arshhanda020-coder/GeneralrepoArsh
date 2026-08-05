//
//  ThemeColorSettings.swift
//  ArshHabitTracker
//
//  Every color token in the app is overridable from Settings > Appearance.
//  These are the built-in defaults (a clean light palette) — an override in
//  UserDefaults wins when present.
//

import Foundation

enum ThemeToken: String, CaseIterable, Identifiable {
    case background, card, cardBorder, dimText, primaryText
    case accent, terminalGreen, terminalAmber
    case reactorCore, reactorDeep, reactorGlow

    var id: String { rawValue }

    var defaultHex: String {
        switch self {
        case .background: return "F7F5F1"
        case .card: return "FFFFFF"
        case .cardBorder: return "E3DFD6"
        case .dimText: return "756F63"
        case .primaryText: return "211D17"
        case .accent: return "B8935B"
        case .terminalGreen: return "4F7A5B"
        case .terminalAmber: return "A8791E"
        case .reactorCore: return "8B6FD6"
        case .reactorDeep: return "1B1330"
        case .reactorGlow: return "5B4FA8"
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
        case .reactorCore: return "Reactor Core"
        case .reactorDeep: return "Reactor Deep"
        case .reactorGlow: return "Reactor Glow"
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

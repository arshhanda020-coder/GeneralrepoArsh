//
//  ThemeColorSettings.swift
//  Odysseus
//
//  Every color token in the app is overridable from Settings > Appearance.
//  These are the built-in defaults — a plain, native-feeling palette modeled
//  on Notes/iMessage/X: warm paper and white cards in light mode, true black
//  in dark mode (like X and iMessage's dark modes), near-black/white text,
//  hairline dividers instead of glowing borders, and the system blue used by
//  iMessage as the one signature accent everywhere. An override in
//  UserDefaults wins when present, and — to keep one ColorPicker per token
//  instead of two — applies to both light and dark mode alike.
//

import Foundation

enum ThemeToken: String, CaseIterable, Identifiable {
    case background, card, cardBorder, dimText, primaryText
    case accent, terminalGreen, terminalAmber, negative
    case reactorCore, reactorDeep, reactorGlow
    case nebulaWispB, nebulaWispC, reactorAccentB

    var id: String { rawValue }

    /// Light-mode default — Notes-app paper background, white cards, iMessage
    /// system blue accent.
    var defaultHexLight: String {
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

    /// Dark-mode default — true black like X and iMessage's dark modes, with
    /// Apple's own dark-mode system color adjustments (brighter blue/green/
    /// orange/red so they still hold contrast against black).
    var defaultHexDark: String {
        switch self {
        case .background: return "000000"
        case .card: return "121212"
        case .cardBorder: return "2F3336"
        case .dimText: return "8E8E93"
        case .primaryText: return "E7E9EA"
        case .accent: return "0A84FF"
        case .terminalGreen: return "30D158"
        case .terminalAmber: return "FF9F0A"
        case .negative: return "FF453A"
        case .reactorCore: return "FFFFFF"
        case .reactorDeep: return "000000"
        case .reactorGlow: return "0A84FF"
        case .nebulaWispB: return "64D2FF"
        case .nebulaWispC: return "98989D"
        case .reactorAccentB: return "FF9F0A"
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
        case .reactorCore: return "Assistant Core"
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

    /// A user override from Settings > Appearance, if set — applies to both
    /// light and dark mode, since Appearance exposes one picker per token.
    static func overrideHex(for token: ThemeToken) -> String? {
        UserDefaults.standard.string(forKey: key(token))
    }

    static func lightHex(for token: ThemeToken) -> String {
        overrideHex(for: token) ?? token.defaultHexLight
    }

    static func darkHex(for token: ThemeToken) -> String {
        overrideHex(for: token) ?? token.defaultHexDark
    }

    static func setHex(_ hex: String, for token: ThemeToken) {
        UserDefaults.standard.set(hex, forKey: key(token))
    }

    static func resetAll() {
        for token in ThemeToken.allCases { UserDefaults.standard.removeObject(forKey: key(token)) }
    }
}

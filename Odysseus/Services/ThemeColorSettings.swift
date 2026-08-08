//
//  ThemeColorSettings.swift
//  Odysseus
//
//  Every color token in the app is overridable from Settings > Appearance.
//  These are the built-in defaults — a calm, matte palette that follows the
//  system's light/dark setting instead of forcing dark everywhere: warm
//  paper/white in light mode, graphite/near-black in dark mode, the same
//  quiet emerald signature accent in both, and exactly one gold used
//  sparingly for highlights (never as a base color) instead of a saturated
//  hue everywhere. An override in UserDefaults wins when present, and — to
//  keep one ColorPicker per token instead of two — applies to both light
//  and dark mode alike.
//

import Foundation

enum ThemeToken: String, CaseIterable, Identifiable {
    case background, card, cardBorder, dimText, primaryText
    case accent, terminalGreen, terminalAmber, negative
    case reactorCore, reactorDeep, reactorGlow
    case nebulaWispB, nebulaWispC, reactorAccentB

    var id: String { rawValue }

    /// Light-mode default — warm paper background, white cards, and
    /// deepened signal colors (green/amber/red) so they still hold contrast
    /// against a light surface instead of washing out.
    var defaultHexLight: String {
        switch self {
        case .background: return "F4F3F0"
        case .card: return "FFFFFF"
        case .cardBorder: return "E3E1DA"
        case .dimText: return "5E6664"
        case .primaryText: return "1C201E"
        case .accent: return "2F8577"
        case .terminalGreen: return "2E8F5B"
        case .terminalAmber: return "9C7A1B"
        case .negative: return "B6493E"
        case .reactorCore: return "2F6E5F"
        case .reactorDeep: return "060907"
        case .reactorGlow: return "3FA98F"
        case .nebulaWispB: return "4F8FA8"
        case .nebulaWispC: return "8A7C6B"
        case .reactorAccentB: return "9C7A1B"
        }
    }

    /// Dark-mode default — near-black graphite voids, the same signature
    /// emerald accent, and exactly one gold used sparingly for highlights.
    var defaultHexDark: String {
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
        case .reactorCore: return "Reactor Core"
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

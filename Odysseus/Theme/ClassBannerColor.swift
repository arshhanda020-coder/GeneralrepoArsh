//
//  ClassBannerColor.swift
//  Odysseus
//
//  Google Classroom-style banner palette: a fixed set of flat, saturated
//  hues a class card/detail header can be tinted with. Deliberately fixed
//  hex (like MindMapSection's per-section accents), not routed through
//  ThemeColorSettings — a class banner is a per-class label color, not a
//  global theme token, so it stays put across light/dark mode the same way
//  Classroom's do. Surrounding chrome (text, card backgrounds) still reads
//  through Theme so the rest of the screen respects light/dark.
//

import SwiftUI

enum ClassBannerColor: Int, CaseIterable, Identifiable {
    case ocean, teal, violet, raspberry, amber, forest, indigo, terracotta, slate, plum

    var id: Int { rawValue }

    /// Top-of-banner hex.
    private var baseHex: String {
        switch self {
        case .ocean: return "1A73E8"
        case .teal: return "009688"
        case .violet: return "7C4DFF"
        case .raspberry: return "E91E63"
        case .amber: return "F9A825"
        case .forest: return "2E7D32"
        case .indigo: return "3F51B5"
        case .terracotta: return "D84315"
        case .slate: return "546E7A"
        case .plum: return "8E24AA"
        }
    }

    /// Bottom-of-banner hex — a deeper shade of the same hue, for a subtle
    /// top-to-bottom gradient instead of a flat block. Still matte: no
    /// diagonal sheen, no glow, just two stops of one hue.
    private var deepHex: String {
        switch self {
        case .ocean: return "0B57BE"
        case .teal: return "00695C"
        case .violet: return "5C35CC"
        case .raspberry: return "AD1457"
        case .amber: return "F57F17"
        case .forest: return "1B5E20"
        case .indigo: return "283593"
        case .terracotta: return "BF360C"
        case .slate: return "37474F"
        case .plum: return "6A1B9A"
        }
    }

    var base: Color { Color(hex: baseHex) }
    var deep: Color { Color(hex: deepHex) }

    var gradient: LinearGradient {
        LinearGradient(colors: [base, deep], startPoint: .top, endPoint: .bottom)
    }

    var displayName: String {
        switch self {
        case .ocean: return "Ocean"
        case .teal: return "Teal"
        case .violet: return "Violet"
        case .raspberry: return "Raspberry"
        case .amber: return "Amber"
        case .forest: return "Forest"
        case .indigo: return "Indigo"
        case .terracotta: return "Terracotta"
        case .slate: return "Slate"
        case .plum: return "Plum"
        }
    }

    /// Stable pick for a class that hasn't chosen a color explicitly —
    /// hashes the class's id so the auto-assigned color doesn't shuffle
    /// between launches (Swift's `Hasher` is seeded per-process, so a plain
    /// `.hashValue` would).
    static func auto(for id: String) -> ClassBannerColor {
        var hash: UInt64 = 14695981039346656037
        for byte in id.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 1099511628211
        }
        return allCases[Int(hash % UInt64(allCases.count))]
    }
}

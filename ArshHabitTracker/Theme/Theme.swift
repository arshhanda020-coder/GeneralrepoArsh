//
//  Theme.swift
//  ArshHabitTracker
//

import SwiftUI

enum Theme {
    static let background = Color(hex: "0B0F14")
    static let card = Color(hex: "151B23")
    static let cardBorder = Color(hex: "232B36")
    static let dimText = Color(hex: "8A94A3")

    /// The app's one signature accent — muted brass, used for interactive
    /// elements (buttons, links, the nav tint) across the whole app instead
    /// of a different saturated color per section.
    static let accent = Color(hex: "B8935B")

    /// Semantic states — kept distinct from `accent` but desaturated to match
    /// a quieter, more deliberate palette.
    static let terminalGreen = Color(hex: "7FA285")
    static let terminalAmber = Color(hex: "C9A227")

    /// Arc-reactor palette — home screen and Jarvis mode. Matches `accent` so
    /// the whole app reads as one design instead of Jarvis being a separate
    /// neon exception.
    static let reactorCore = Color(hex: "C9A227")
    static let reactorDeep = Color(hex: "15110A")
    static let reactorGlow = Color(hex: "8A6E3D")
}

extension Color {
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        sanitized = sanitized.hasPrefix("#") ? String(sanitized.dropFirst()) : sanitized
        var value: UInt64 = 0
        Scanner(string: sanitized).scanHexInt64(&value)
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

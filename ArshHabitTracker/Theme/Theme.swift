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

    /// Legacy accents kept for other screens.
    static let terminalGreen = Color(hex: "4ADE80")
    static let terminalAmber = Color(hex: "FFB000")

    /// Arc-reactor palette — used only by the home screen and Jarvis mode.
    /// Fully-saturated, high-contrast — an instrument light, not a soft glow.
    static let reactorCore = Color(hex: "00D9FF")
    static let reactorDeep = Color(hex: "001824")
    static let reactorGlow = Color(hex: "0090C2")
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

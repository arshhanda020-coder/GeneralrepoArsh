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
    /// Cool steel-blue, not bright/pastel — closer to a HUD readout than a toy.
    static let reactorCore = Color(hex: "AFC9DE")
    static let reactorDeep = Color(hex: "0A1826")
    static let reactorGlow = Color(hex: "3E6E96")
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

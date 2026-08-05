//
//  Theme.swift
//  ArshHabitTracker
//
//  Every value here reads through ThemeColorSettings, so Settings >
//  Appearance can override any of them; the hex values in
//  ThemeColorSettings/ThemeToken are just the defaults.
//

import SwiftUI
import UIKit

enum Theme {
    static var background: Color { Color(hex: ThemeColorSettings.hex(for: .background)) }
    static var card: Color { Color(hex: ThemeColorSettings.hex(for: .card)) }
    static var cardBorder: Color { Color(hex: ThemeColorSettings.hex(for: .cardBorder)) }
    static var dimText: Color { Color(hex: ThemeColorSettings.hex(for: .dimText)) }
    /// Primary text color — near-black on the default light background.
    static var primaryText: Color { Color(hex: ThemeColorSettings.hex(for: .primaryText)) }

    /// The app's one signature accent — used for interactive elements
    /// (buttons, links, the nav tint) across the whole app.
    static var accent: Color { Color(hex: ThemeColorSettings.hex(for: .accent)) }

    static var terminalGreen: Color { Color(hex: ThemeColorSettings.hex(for: .terminalGreen)) }
    static var terminalAmber: Color { Color(hex: ThemeColorSettings.hex(for: .terminalAmber)) }

    /// Nebula palette — the reactor visual (home screen centerpiece, Jarvis
    /// mode, mind-map connectors) and every "themed around it" accent.
    static var reactorCore: Color { Color(hex: ThemeColorSettings.hex(for: .reactorCore)) }
    static var reactorDeep: Color { Color(hex: ThemeColorSettings.hex(for: .reactorDeep)) }
    static var reactorGlow: Color { Color(hex: ThemeColorSettings.hex(for: .reactorGlow)) }
    static var nebulaWispB: Color { Color(hex: ThemeColorSettings.hex(for: .nebulaWispB)) }
    static var nebulaWispC: Color { Color(hex: ThemeColorSettings.hex(for: .nebulaWispC)) }
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

    /// Best-effort hex round-trip for the Appearance color pickers.
    var hexString: String {
        let uiColor = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

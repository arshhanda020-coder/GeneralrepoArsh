//
//  Theme.swift
//  Odysseus
//
//  Every value here reads through ThemeColorSettings, so Settings >
//  Appearance can override any of them; the hex values in
//  ThemeColorSettings/ThemeToken are just the defaults. Each color adapts to
//  the system's light/dark setting automatically (the app no longer forces
//  dark mode) via the light/dark Color initializer below.
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#elseif canImport(AppKit)
import AppKit
#endif

enum Theme {
    static var background: Color { Color(token: .background) }
    static var card: Color { Color(token: .card) }
    static var cardBorder: Color { Color(token: .cardBorder) }
    static var dimText: Color { Color(token: .dimText) }
    /// Primary text color — near-black on light backgrounds, near-white on dark.
    static var primaryText: Color { Color(token: .primaryText) }

    /// The app's one signature accent — used for interactive elements
    /// (buttons, links, the nav tint) across the whole app.
    static var accent: Color { Color(token: .accent) }

    static var terminalGreen: Color { Color(token: .terminalGreen) }
    static var terminalAmber: Color { Color(token: .terminalAmber) }
    /// The one error/alert/destructive red used everywhere — previously two
    /// different hardcoded reds (FF6B6B and C0605C) were sprinkled across
    /// ~30 files for the same meaning; this is the single source now.
    static var negative: Color { Color(token: .negative) }

    /// Nebula palette — the reactor visual (home screen centerpiece, Odysseus
    /// mode, mind-map connectors) and every "themed around it" accent.
    static var reactorCore: Color { Color(token: .reactorCore) }
    static var reactorDeep: Color { Color(token: .reactorDeep) }
    static var reactorGlow: Color { Color(token: .reactorGlow) }
    static var nebulaWispB: Color { Color(token: .nebulaWispB) }
    static var nebulaWispC: Color { Color(token: .nebulaWispC) }
    static var reactorAccentB: Color { Color(token: .reactorAccentB) }
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

    /// A color that resolves to a different hex in light vs. dark mode,
    /// switching live as the system appearance changes (unlike a plain
    /// `Color(hex:)`, which is fixed the moment it's created).
    init(hexLight: String, hexDark: String) {
        #if canImport(UIKit)
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(Color(hex: hexDark)) : UIColor(Color(hex: hexLight))
        })
        #elseif canImport(AppKit)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(Color(hex: isDark ? hexDark : hexLight))
        })
        #else
        self.init(hex: hexDark)
        #endif
    }

    /// Convenience for reading a `ThemeToken` as an adaptive light/dark color.
    init(token: ThemeToken) {
        self.init(hexLight: ThemeColorSettings.lightHex(for: token), hexDark: ThemeColorSettings.darkHex(for: token))
    }

    /// Best-effort hex round-trip for the Appearance color pickers. Reads
    /// back whatever the picker is currently showing on screen, so it stays
    /// correct in both light and dark mode without needing to know which.
    var hexString: String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        #if canImport(UIKit)
        UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &a)
        #elseif canImport(AppKit)
        (NSColor(self).usingColorSpace(.deviceRGB) ?? NSColor(self)).getRed(&r, green: &g, blue: &b, alpha: &a)
        #endif
        return String(format: "%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

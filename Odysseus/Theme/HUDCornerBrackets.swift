//
//  HUDCornerBrackets.swift
//  Odysseus
//
//  The signature "framed viewport" mark of the HUD command-console look —
//  four L-shaped corner brackets, modeled directly on a reference screenshot
//  the user provided. Applied once, globally, in RootView so every screen
//  in the app gets the same framed-console feel automatically.
//

import SwiftUI

struct HUDCornerBrackets: View {
    var color: Color = Theme.reactorGlow.opacity(0.45)
    var length: CGFloat = 20
    var inset: CGFloat = 6
    var lineWidth: CGFloat = 1.5

    var body: some View {
        GeometryReader { geo in
            Path { path in
                // Top-left
                path.move(to: CGPoint(x: inset, y: inset + length))
                path.addLine(to: CGPoint(x: inset, y: inset))
                path.addLine(to: CGPoint(x: inset + length, y: inset))
                // Top-right
                path.move(to: CGPoint(x: geo.size.width - inset - length, y: inset))
                path.addLine(to: CGPoint(x: geo.size.width - inset, y: inset))
                path.addLine(to: CGPoint(x: geo.size.width - inset, y: inset + length))
                // Bottom-left
                path.move(to: CGPoint(x: inset, y: geo.size.height - inset - length))
                path.addLine(to: CGPoint(x: inset, y: geo.size.height - inset))
                path.addLine(to: CGPoint(x: inset + length, y: geo.size.height - inset))
                // Bottom-right
                path.move(to: CGPoint(x: geo.size.width - inset - length, y: geo.size.height - inset))
                path.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height - inset))
                path.addLine(to: CGPoint(x: geo.size.width - inset, y: geo.size.height - inset - length))
            }
            .stroke(color, lineWidth: lineWidth)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

extension View {
    /// The whole-app HUD frame — corner brackets pinned over this view,
    /// non-interactive so nothing underneath is blocked.
    func hudFramed() -> some View {
        overlay(HUDCornerBrackets())
    }
}

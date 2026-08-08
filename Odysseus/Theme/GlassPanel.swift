//
//  GlassPanel.swift
//  Odysseus
//
//  The app's flat card surface — a plain white/card-colored tile with a
//  hairline border and a whisper-soft drop shadow, the way Notes, Messages,
//  and Settings rows read as "a card" without looking like tinted glass.
//  One shared modifier so every card/tile/badge in the app reads as the
//  same material. (Named glassPanel for call-site compatibility with the
//  ~40 existing usages; the material itself is intentionally flat now.)
//

import SwiftUI

private struct GlassPanel<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color = Theme.card
    var borderColor: Color = Theme.cardBorder

    func body(content: Content) -> some View {
        content
            .background(shape.fill(tint))
            .overlay(shape.stroke(borderColor, lineWidth: 1))
            .clipShape(shape)
            .shadow(color: Color.black.opacity(0.05), radius: 3, y: 1)
    }
}

extension View {
    /// Flat card with a rounded-rect silhouette — the default surface across
    /// the app (list rows, section tiles, badges).
    func glassPanel(
        cornerRadius: CGFloat = 8,
        tint: Color = Theme.card,
        tintOpacity: Double = 1,
        borderColor: Color = Theme.cardBorder,
        borderOpacity: Double = 1,
        glow: Color? = nil,
        glowRadius: CGFloat = 6
    ) -> some View {
        modifier(
            GlassPanel(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint.opacity(tintOpacity),
                borderColor: borderColor.opacity(borderOpacity)
            )
        )
    }

    /// Flat card with a capsule silhouette — status pills/badges.
    func glassCapsule(
        tint: Color = Theme.card,
        tintOpacity: Double = 1,
        borderColor: Color = Theme.cardBorder,
        borderOpacity: Double = 1,
        glow: Color? = nil,
        glowRadius: CGFloat = 6
    ) -> some View {
        modifier(
            GlassPanel(
                shape: Capsule(),
                tint: tint.opacity(tintOpacity),
                borderColor: borderColor.opacity(borderOpacity)
            )
        )
    }
}

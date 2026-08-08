//
//  GlassPanel.swift
//  Odysseus
//
//  The app's shared card/tile/badge surface — flat and matte: a solid tinted
//  fill and a single hairline border, no diagonal gloss sheen and no colored
//  glow. Those used to layer on top of every card (a bright specular streak
//  plus a `.shadow` in the section's accent color) and made the whole app
//  read as glossy/neon — genuinely hard to look at for long stretches. This
//  is the calmer alternative, closer to how a Messages bubble or a plain
//  Settings row reads: one quiet fill, one quiet edge. A few HUD panels
//  (the reactor's status readouts, Odysseus mode) still pass a lower
//  `tintOpacity` for a translucent console feel — the `.ultraThinMaterial`
//  backing is kept for exactly that case — but the default is solid.
//

import SwiftUI

private struct GlassPanel<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color = Theme.card
    var tintOpacity: Double = 0.92
    var borderColor: Color = Theme.cardBorder
    var borderOpacity: Double = 0.9
    // Kept so existing call sites don't need to change, but a matte surface
    // never glows — both are ignored now.
    var glow: Color? = nil
    var glowRadius: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background(shape.fill(.ultraThinMaterial))
            .background(shape.fill(tint.opacity(tintOpacity)))
            .clipShape(shape)
            .overlay(shape.stroke(borderColor.opacity(borderOpacity), lineWidth: 1))
    }
}

extension View {
    /// Flat matte panel with a rounded-rect silhouette — the default card
    /// surface across the app (mind-map tiles, HUD readouts, news cards).
    func glassPanel(
        cornerRadius: CGFloat = 8,
        tint: Color = Theme.card,
        tintOpacity: Double = 0.92,
        borderColor: Color = Theme.cardBorder,
        borderOpacity: Double = 0.9,
        glow: Color? = nil,
        glowRadius: CGFloat = 6
    ) -> some View {
        modifier(
            GlassPanel(
                shape: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous),
                tint: tint, tintOpacity: tintOpacity,
                borderColor: borderColor, borderOpacity: borderOpacity,
                glow: glow, glowRadius: glowRadius
            )
        )
    }

    /// Flat matte panel with a capsule silhouette — status pills/badges.
    func glassCapsule(
        tint: Color = Theme.card,
        tintOpacity: Double = 0.92,
        borderColor: Color = Theme.cardBorder,
        borderOpacity: Double = 0.9,
        glow: Color? = nil,
        glowRadius: CGFloat = 6
    ) -> some View {
        modifier(
            GlassPanel(
                shape: Capsule(),
                tint: tint, tintOpacity: tintOpacity,
                borderColor: borderColor, borderOpacity: borderOpacity,
                glow: glow, glowRadius: glowRadius
            )
        )
    }
}

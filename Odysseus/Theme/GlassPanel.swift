//
//  GlassPanel.swift
//  Odysseus
//
//  The "transparent glossy" HUD surface — a frosted glass tile with a
//  diagonal specular sheen (like light catching curved glass) and a glowing
//  edge, instead of a flat tinted rectangle. One shared modifier so every
//  card/tile/badge in the app reads as the same material.
//

import SwiftUI

private struct GlassPanel<S: Shape>: ViewModifier {
    let shape: S
    var tint: Color = Theme.card
    var tintOpacity: Double = 0.45
    var borderColor: Color = Theme.cardBorder
    var borderOpacity: Double = 0.5
    var glow: Color? = nil
    var glowRadius: CGFloat = 6

    func body(content: Content) -> some View {
        content
            .background(shape.fill(.ultraThinMaterial))
            .background(shape.fill(tint.opacity(tintOpacity)))
            // Diagonal gloss sheen — a bright streak top-leading, fading to
            // nothing by bottom-trailing, the way light rakes across glass.
            .overlay(
                shape
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.38),
                                Color.white.opacity(0.12),
                                Color.clear,
                                Color.clear,
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
            )
            .clipShape(shape)
            // Crisp specular edge along the top — the highlight where a
            // curved glass surface catches direct light, distinct from the
            // dimmer tinted border running the rest of the way round.
            .overlay(
                shape.stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.75),
                            borderColor.opacity(borderOpacity),
                            borderColor.opacity(borderOpacity * 0.25),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    ),
                    lineWidth: 1.1
                )
            )
            .shadow(color: (glow ?? .clear).opacity(glow == nil ? 0 : 0.5), radius: glowRadius)
    }
}

extension View {
    /// Frosted glass panel with a rounded-rect silhouette — the default card
    /// surface across the app (mind-map tiles, HUD readouts, news cards).
    func glassPanel(
        cornerRadius: CGFloat = 8,
        tint: Color = Theme.card,
        tintOpacity: Double = 0.45,
        borderColor: Color = Theme.cardBorder,
        borderOpacity: Double = 0.5,
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

    /// Frosted glass panel with a capsule silhouette — status pills/badges.
    func glassCapsule(
        tint: Color = Theme.card,
        tintOpacity: Double = 0.45,
        borderColor: Color = Theme.cardBorder,
        borderOpacity: Double = 0.5,
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

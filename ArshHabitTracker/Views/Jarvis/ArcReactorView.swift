//
//  ArcReactorView.swift
//  ArshHabitTracker
//
//  Modeled on a real emission nebula (Dumbbell Nebula reference): a soft,
//  rounded glowing cloud — deep purple/magenta at the edges, blending into a
//  luminous blue-white core — with a continuously rotating, glossy color
//  sweep so the motion is unmistakable, not a subtle blob. Every hue reads
//  through Theme (Settings > Appearance), so it's fully user-customizable.
//  Reused as the home screen's centerpiece and Jarvis mode's focal point.
//

import SwiftUI

/// A smooth closed blob through a fixed ring of (angle, radius) points — a
/// gently rounded, irregular silhouette (not a perfect circle, but not the
/// jagged star-shape of the earlier version either).
private struct BlobShape: Shape {
    let points: [(angle: Double, radiusMultiplier: CGFloat)]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let baseRadius = min(rect.width, rect.height) / 2
        let pts = points.map { point -> CGPoint in
            let r = baseRadius * point.radiusMultiplier
            return CGPoint(
                x: center.x + cos(point.angle * .pi / 180) * r,
                y: center.y + sin(point.angle * .pi / 180) * r
            )
        }
        guard pts.count > 2 else { return Path() }

        var path = Path()
        func midpoint(_ a: CGPoint, _ b: CGPoint) -> CGPoint {
            CGPoint(x: (a.x + b.x) / 2, y: (a.y + b.y) / 2)
        }
        path.move(to: midpoint(pts[pts.count - 1], pts[0]))
        for i in 0..<pts.count {
            let next = pts[(i + 1) % pts.count]
            path.addQuadCurve(to: midpoint(pts[i], next), control: pts[i])
        }
        path.closeSubpath()
        return path
    }
}

struct ArcReactorView: View {
    var size: CGFloat = 120
    var isActive: Bool = false

    @State private var rotation: Double = 0
    @State private var swirl: Double = 0
    @State private var pulseUp = false
    @State private var starSeeds: [StarSeed] = (0..<28).map { _ in StarSeed() }

    private struct StarSeed {
        let angle = Double.random(in: 0..<360)
        let radiusFraction = Double.random(in: 0.3...0.85)
        let sizeFraction = Double.random(in: 0.008...0.02)
        let twinkleDelay = Double.random(in: 0...2.4)
    }

    private static let coreHighlight = Color(hex: "FFFFFF")

    /// Gentle, rounded undulation — soft like the reference photo, not a spiky star.
    private static let bodyPoints: [(angle: Double, radiusMultiplier: CGFloat)] = [
        (0, 0.94), (30, 1.0), (60, 0.9), (90, 1.02), (120, 0.92),
        (150, 0.98), (180, 0.88), (210, 1.0), (240, 0.9), (270, 0.96),
        (300, 0.86), (330, 1.0),
    ]

    var body: some View {
        ZStack {
            // Wide, soft outer glow.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.reactorGlow.opacity(isActive ? 0.45 : 0.28), .clear],
                        center: .center, startRadius: 0, endRadius: size * 0.62
                    )
                )
                .frame(width: size * 1.3, height: size * 1.3)
                .blur(radius: size * 0.06)
                .scaleEffect(pulseUp ? 1.06 : 0.97)

            // The cloud body — continuously rotating angular sweep of the full
            // palette gives obvious, glossy motion (not just a static tint).
            BlobShape(points: Self.bodyPoints)
                .fill(
                    AngularGradient(
                        colors: [
                            Theme.reactorGlow,
                            Theme.nebulaWispB,
                            Theme.nebulaWispC,
                            Theme.reactorCore,
                            Theme.nebulaWispB,
                            Theme.reactorGlow,
                        ],
                        center: .center,
                        angle: .degrees(swirl)
                    )
                )
                .overlay(
                    // Glossy highlight sweep — a bright soft patch that drifts,
                    // reads as a specular sheen across the gas.
                    BlobShape(points: Self.bodyPoints)
                        .fill(
                            RadialGradient(
                                colors: [Self.coreHighlight.opacity(0.85), Theme.reactorCore.opacity(0.35), .clear],
                                center: UnitPoint(
                                    x: 0.5 + cos(rotation * .pi / 180) * 0.16,
                                    y: 0.42 + sin(rotation * .pi / 180) * 0.1
                                ),
                                startRadius: 0,
                                endRadius: size * 0.34
                            )
                        )
                )
                .overlay(
                    BlobShape(points: Self.bodyPoints)
                        .fill(RadialGradient(colors: [.clear, Theme.reactorDeep.opacity(0.5)], center: .center, startRadius: size * 0.28, endRadius: size * 0.5))
                )
                .overlay(BlobShape(points: Self.bodyPoints).stroke(Theme.reactorCore.opacity(0.3), lineWidth: 1))
                .blur(radius: size * 0.012)
                .shadow(color: Theme.reactorGlow.opacity(isActive ? 0.7 : 0.4), radius: isActive ? 16 : 9)

            // Bright core point.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Self.coreHighlight, Theme.reactorCore.opacity(0.0)],
                        center: .center, startRadius: 0, endRadius: size * 0.1
                    )
                )
                .frame(width: size * 0.16, height: size * 0.16)
                .scaleEffect(pulseUp ? 1.15 : 0.9)
                .position(x: size / 2, y: size / 2)

            // Scattered stars, independently twinkling.
            ForEach(Array(starSeeds.enumerated()), id: \.offset) { _, star in
                Circle()
                    .fill(.white)
                    .frame(width: size * star.sizeFraction, height: size * star.sizeFraction)
                    .offset(
                        x: cos(star.angle * .pi / 180) * size * star.radiusFraction,
                        y: sin(star.angle * .pi / 180) * size * star.radiusFraction
                    )
                    .opacity(pulseUp ? 0.9 : 0.3)
                    .animation(
                        .easeInOut(duration: 1.8).repeatForever(autoreverses: true).delay(star.twinkleDelay),
                        value: pulseUp
                    )
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.linear(duration: 14).repeatForever(autoreverses: false)) {
                swirl = 360
            }
            withAnimation(.linear(duration: 22).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: isActive ? 0.6 : 2.2).repeatForever(autoreverses: true)) {
                pulseUp = true
            }
        }
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        ArcReactorView(size: 220, isActive: true)
    }
}

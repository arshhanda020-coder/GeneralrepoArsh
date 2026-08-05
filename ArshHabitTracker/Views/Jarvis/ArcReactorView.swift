//
//  ArcReactorView.swift
//  ArshHabitTracker
//
//  Modeled on a real emission nebula: an irregular, ragged-edged gas cloud
//  (never a clean circle) with thin bright filament threads webbing through
//  a teal core, and jagged orange/red/green wisps trailing off unevenly at
//  the edges. Every hue reads through Theme (Settings > Appearance), so the
//  nebula's colors are fully user-customizable. Reused as the home screen's
//  centerpiece and Jarvis mode's focal point.
//

import SwiftUI

/// A smooth closed blob through a fixed ring of (angle, radius) points —
/// this is what breaks the "perfect circle" look. Points are hand-jittered,
/// not randomized at runtime, so the silhouette doesn't reshuffle every redraw.
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

/// A jagged, glowing thread through the core — the "cracked filament web"
/// visible in real nebula photos.
private struct FilamentPath: Shape {
    let controlOffsets: [CGVector]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        guard let first = controlOffsets.first else { return path }
        path.move(to: CGPoint(x: center.x + first.dx * radius, y: center.y + first.dy * radius))
        for offset in controlOffsets.dropFirst() {
            path.addLine(to: CGPoint(x: center.x + offset.dx * radius, y: center.y + offset.dy * radius))
        }
        return path
    }
}

struct ArcReactorView: View {
    var size: CGFloat = 120
    var isActive: Bool = false

    @State private var drift: Double = 0
    @State private var pulseUp = false
    @State private var starSeeds: [StarSeed] = (0..<30).map { _ in StarSeed() }

    private struct StarSeed {
        let angle = Double.random(in: 0..<360)
        let radiusFraction = Double.random(in: 0.35...0.85)
        let sizeFraction = Double.random(in: 0.008...0.022)
        let twinkleDelay = Double.random(in: 0...2.4)
    }

    private static let coreHighlight = Color(hex: "F5FFFD")

    /// The nebula's overall ragged silhouette — deliberately uneven radii, not a circle.
    private static let bodyPoints: [(angle: Double, radiusMultiplier: CGFloat)] = [
        (0, 0.82), (35, 0.95), (70, 0.68), (100, 0.9), (130, 0.6),
        (165, 0.88), (195, 0.7), (225, 0.98), (255, 0.62), (285, 0.85),
        (320, 0.72), (350, 0.9),
    ]

    private static let haloPoints: [(angle: Double, radiusMultiplier: CGFloat)] = [
        (10, 1.05), (50, 0.82), (85, 1.12), (120, 0.78), (155, 1.08),
        (190, 0.85), (220, 1.15), (250, 0.8), (280, 1.1), (315, 0.86), (345, 1.0),
    ]

    private struct Wisp {
        let color: Color
        let center: CGPoint
        let points: [(angle: Double, radiusMultiplier: CGFloat)]
        let scale: CGSize
        let rotationOffset: Double
        let spinsClockwise: Bool
    }

    private var wisps: [Wisp] {
        let a = Theme.reactorGlow
        let b = Theme.nebulaWispB
        let c = Theme.nebulaWispC
        let jaggedPoints: [(angle: Double, radiusMultiplier: CGFloat)] = [
            (0, 0.9), (60, 0.55), (120, 1.0), (180, 0.6), (240, 0.95), (300, 0.5),
        ]
        return [
            Wisp(color: a, center: CGPoint(x: 0.32, y: -0.28), points: jaggedPoints, scale: CGSize(width: 0.5, height: 0.22), rotationOffset: 15, spinsClockwise: true),
            Wisp(color: b, center: CGPoint(x: -0.35, y: -0.18), points: jaggedPoints, scale: CGSize(width: 0.46, height: 0.2), rotationOffset: 100, spinsClockwise: false),
            Wisp(color: c, center: CGPoint(x: -0.1, y: 0.36), points: jaggedPoints, scale: CGSize(width: 0.5, height: 0.24), rotationOffset: 190, spinsClockwise: true),
            Wisp(color: a, center: CGPoint(x: 0.34, y: 0.3), points: jaggedPoints, scale: CGSize(width: 0.42, height: 0.19), rotationOffset: 250, spinsClockwise: false),
            Wisp(color: b, center: CGPoint(x: -0.36, y: 0.3), points: jaggedPoints, scale: CGSize(width: 0.4, height: 0.18), rotationOffset: 300, spinsClockwise: true),
        ]
    }

    private static let filaments: [[CGVector]] = [
        [CGVector(dx: -0.05, dy: -0.42), CGVector(dx: 0.08, dy: -0.18), CGVector(dx: -0.1, dy: 0.02), CGVector(dx: 0.12, dy: 0.24), CGVector(dx: -0.02, dy: 0.44)],
        [CGVector(dx: -0.4, dy: -0.08), CGVector(dx: -0.14, dy: 0.02), CGVector(dx: 0.1, dy: -0.08), CGVector(dx: 0.3, dy: 0.1), CGVector(dx: 0.44, dy: -0.02)],
        [CGVector(dx: -0.28, dy: -0.3), CGVector(dx: -0.06, dy: -0.1), CGVector(dx: 0.02, dy: 0.14), CGVector(dx: 0.24, dy: 0.28)],
        [CGVector(dx: 0.3, dy: -0.26), CGVector(dx: 0.08, dy: -0.06), CGVector(dx: -0.06, dy: 0.12), CGVector(dx: -0.26, dy: 0.3)],
    ]

    var body: some View {
        ZStack {
            // Faint outer halo — soft, irregular, wide.
            BlobShape(points: Self.haloPoints)
                .fill(Theme.reactorCore.opacity(isActive ? 0.28 : 0.16))
                .blur(radius: size * 0.1)
                .scaleEffect(pulseUp ? 1.05 : 0.96)

            // The nebula body itself — ragged silhouette, never a circle.
            BlobShape(points: Self.bodyPoints)
                .fill(Theme.reactorDeep)
                .overlay(
                    ZStack {
                        ForEach(Array(wisps.enumerated()), id: \.offset) { _, wisp in
                            BlobShape(points: wisp.points)
                                .fill(
                                    RadialGradient(
                                        colors: [wisp.color.opacity(0.9), wisp.color.opacity(0.0)],
                                        center: .center, startRadius: 0, endRadius: size * 0.22
                                    )
                                )
                                .frame(width: size * wisp.scale.width, height: size * wisp.scale.height)
                                .position(x: size / 2 + wisp.center.x * size, y: size / 2 + wisp.center.y * size)
                                .rotationEffect(.degrees((wisp.spinsClockwise ? drift : -drift) + wisp.rotationOffset))
                                .blur(radius: size * 0.035)
                        }

                        ForEach(Array(Self.filaments.enumerated()), id: \.offset) { index, filament in
                            let path = FilamentPath(controlOffsets: filament)
                            ZStack {
                                path.stroke(Theme.reactorCore.opacity(0.55), style: StrokeStyle(lineWidth: size * 0.05, lineCap: .round, lineJoin: .round))
                                    .blur(radius: size * 0.03)
                                path.stroke(Self.coreHighlight.opacity(0.9), style: StrokeStyle(lineWidth: size * 0.012, lineCap: .round, lineJoin: .round))
                            }
                            .frame(width: size, height: size)
                            .opacity(pulseUp ? 1 : 0.6)
                            .animation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(Double(index) * 0.3), value: pulseUp)
                        }

                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [Self.coreHighlight, Theme.reactorCore.opacity(0.0)],
                                    center: .center, startRadius: 0, endRadius: size * 0.13
                                )
                            )
                            .frame(width: size * 0.22, height: size * 0.22)
                            .scaleEffect(pulseUp ? 1.1 : 0.92)
                    }
                    .clipShape(BlobShape(points: Self.bodyPoints))
                )

            // Scattered stars around and past the nebula's edge.
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
        .shadow(color: Theme.reactorCore.opacity(isActive ? 0.55 : 0.3), radius: isActive ? 14 : 8)
        .onAppear {
            withAnimation(.linear(duration: 60).repeatForever(autoreverses: false)) {
                drift = 360
            }
            withAnimation(.easeInOut(duration: isActive ? 0.6 : 2.4).repeatForever(autoreverses: true)) {
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

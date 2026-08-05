//
//  ArcReactorView.swift
//  ArshHabitTracker
//
//  Modeled on a real emission nebula: a dark void, a bright filament core,
//  and wisps trailing off the edges — each layer drifts and rotates
//  independently so it reads as a living gas cloud, not a flat spinning
//  disc. Every hue reads through Theme (Settings > Appearance), so the
//  nebula's colors are fully user-customizable. Reused as the home screen's
//  centerpiece and Jarvis mode's focal point.
//

import SwiftUI

private struct Wisp {
    let color: Color
    let angle: Double
    let radiusFraction: CGFloat
    let widthFraction: CGFloat
    let heightFraction: CGFloat
    let rotationOffset: Double
    let spinsClockwise: Bool
}

struct ArcReactorView: View {
    var size: CGFloat = 120
    var isActive: Bool = false

    @State private var drift: Double = 0
    @State private var pulseUp = false
    @State private var starSeeds: [StarSeed] = (0..<26).map { _ in StarSeed() }

    private struct StarSeed {
        let angle = Double.random(in: 0..<360)
        let radiusFraction = Double.random(in: 0.15...0.5)
        let sizeFraction = Double.random(in: 0.01...0.026)
        let twinkleDelay = Double.random(in: 0...2.4)
    }

    /// Hot core highlight — stays near-white regardless of the surrounding
    /// nebula hue, same as real emission-nebula cores.
    private static let coreHighlight = Color(hex: "F5FFFD")

    private var wisps: [Wisp] {
        let a = Theme.reactorGlow
        let b = Theme.nebulaWispB
        let c = Theme.nebulaWispC
        return [
            Wisp(color: a, angle: 18, radiusFraction: 0.30, widthFraction: 0.42, heightFraction: 0.16, rotationOffset: 0, spinsClockwise: true),
            Wisp(color: b, angle: 96, radiusFraction: 0.28, widthFraction: 0.38, heightFraction: 0.14, rotationOffset: 40, spinsClockwise: false),
            Wisp(color: c, angle: 165, radiusFraction: 0.32, widthFraction: 0.4, heightFraction: 0.15, rotationOffset: 80, spinsClockwise: true),
            Wisp(color: a, angle: 230, radiusFraction: 0.27, widthFraction: 0.36, heightFraction: 0.13, rotationOffset: 120, spinsClockwise: false),
            Wisp(color: b, angle: 290, radiusFraction: 0.3, widthFraction: 0.4, heightFraction: 0.15, rotationOffset: 160, spinsClockwise: true),
            Wisp(color: c, angle: 335, radiusFraction: 0.26, widthFraction: 0.34, heightFraction: 0.12, rotationOffset: 200, spinsClockwise: false),
        ]
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(Theme.reactorDeep)
                .frame(width: size * 0.96, height: size * 0.96)

            ForEach(Array(wisps.enumerated()), id: \.offset) { _, wisp in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [wisp.color.opacity(0.85), wisp.color.opacity(0.0)],
                            center: .center, startRadius: 0, endRadius: size * wisp.widthFraction * 0.5
                        )
                    )
                    .frame(width: size * wisp.widthFraction, height: size * wisp.heightFraction)
                    .rotationEffect(.degrees(wisp.angle))
                    .offset(
                        x: cos(wisp.angle * .pi / 180) * size * wisp.radiusFraction,
                        y: sin(wisp.angle * .pi / 180) * size * wisp.radiusFraction
                    )
                    .rotationEffect(.degrees((wisp.spinsClockwise ? drift : -drift) * 0.6 + wisp.rotationOffset))
                    .blur(radius: size * 0.045)
                    .opacity(isActive ? 0.95 : 0.75)
            }
            .clipShape(Circle().inset(by: size * 0.03))

            // Bright filament core.
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Self.coreHighlight, Theme.reactorCore.opacity(0.9), Theme.reactorCore.opacity(0.0)],
                            center: .center, startRadius: 0, endRadius: size * 0.24
                        )
                    )
                    .frame(width: size * 0.5, height: size * 0.5)
                    .scaleEffect(pulseUp ? 1.06 : 0.96)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white, Self.coreHighlight.opacity(0.0)],
                            center: .center, startRadius: 0, endRadius: size * 0.09
                        )
                    )
                    .frame(width: size * 0.16, height: size * 0.16)
            }
            .blur(radius: size * 0.012)

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
            .clipShape(Circle().inset(by: size * 0.02))

            Circle()
                .strokeBorder(Theme.reactorCore.opacity(0.25), lineWidth: 1)
                .frame(width: size * 0.96, height: size * 0.96)
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .shadow(color: Theme.reactorCore.opacity(isActive ? 0.6 : 0.35), radius: isActive ? 14 : 8)
        .onAppear {
            withAnimation(.linear(duration: 50).repeatForever(autoreverses: false)) {
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

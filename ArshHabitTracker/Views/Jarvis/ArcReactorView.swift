//
//  ArcReactorView.swift
//  ArshHabitTracker
//
//  A small nebula — a soft violet/blue starfield core with drifting color
//  and a scatter of star-points, not a flat AI-blob circle. Reused as the
//  home screen's centerpiece and Jarvis mode's focal point.
//

import SwiftUI

struct ArcReactorView: View {
    var size: CGFloat = 120
    var isActive: Bool = false

    @State private var rotation: Double = 0
    @State private var swirl: Double = 0
    @State private var pulseUp = false
    @State private var starSeeds: [StarSeed] = (0..<18).map { _ in StarSeed() }

    struct StarSeed {
        let angle = Double.random(in: 0..<360)
        let radiusFraction = Double.random(in: 0.2...0.48)
        let sizeFraction = Double.random(in: 0.015...0.035)
        let twinkleDelay = Double.random(in: 0...2)
    }

    var body: some View {
        ZStack {
            // Outer haze — soft, wide, low-opacity bloom.
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.reactorGlow.opacity(isActive ? 0.5 : 0.32), .clear],
                        center: .center, startRadius: 0, endRadius: size * 0.62
                    )
                )
                .frame(width: size * 1.3, height: size * 1.3)
                .blur(radius: size * 0.06)
                .scaleEffect(pulseUp ? 1.05 : 0.97)

            // Nebula body — layered swirling gradients instead of a flat disc.
            ZStack {
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [
                                Theme.reactorGlow,
                                Theme.reactorCore,
                                Color(hex: "C77DFF").opacity(0.85),
                                Theme.reactorDeep,
                                Theme.reactorGlow,
                            ],
                            center: .center,
                            angle: .degrees(swirl)
                        )
                    )
                    .blur(radius: size * 0.05)

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color(hex: "E7D9FF").opacity(0.9), Theme.reactorCore.opacity(0.3), .clear],
                            center: UnitPoint(x: 0.38, y: 0.36),
                            startRadius: 0,
                            endRadius: size * 0.5
                        )
                    )

                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.clear, Theme.reactorDeep.opacity(0.55)],
                            center: .center, startRadius: size * 0.22, endRadius: size * 0.5
                        )
                    )
            }
            .frame(width: size * 0.86, height: size * 0.86)
            .clipShape(Circle())
            .overlay(Circle().stroke(Theme.reactorGlow.opacity(0.5), lineWidth: 1))
            .shadow(color: Theme.reactorCore.opacity(isActive ? 0.7 : 0.4), radius: isActive ? 16 : 9)

            // Scattered star-points drifting within the nebula.
            ForEach(Array(starSeeds.enumerated()), id: \.offset) { _, star in
                Circle()
                    .fill(.white)
                    .frame(width: size * star.sizeFraction, height: size * star.sizeFraction)
                    .offset(
                        x: cos(star.angle * .pi / 180) * size * star.radiusFraction,
                        y: sin(star.angle * .pi / 180) * size * star.radiusFraction
                    )
                    .opacity(pulseUp ? 0.95 : 0.35)
                    .animation(
                        .easeInOut(duration: 1.6).repeatForever(autoreverses: true).delay(star.twinkleDelay),
                        value: pulseUp
                    )
            }
            .rotationEffect(.degrees(rotation * 0.3))
            .clipShape(Circle().inset(by: size * 0.06))

            // A bright core point, like a star's center.
            Circle()
                .fill(.white)
                .frame(width: size * 0.09, height: size * 0.09)
                .blur(radius: size * 0.01)
                .shadow(color: .white.opacity(0.9), radius: size * 0.06)
        }
        .onAppear {
            withAnimation(.linear(duration: 26).repeatForever(autoreverses: false)) {
                swirl = 360
            }
            withAnimation(.linear(duration: 40).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: isActive ? 0.6 : 2.6).repeatForever(autoreverses: true)) {
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

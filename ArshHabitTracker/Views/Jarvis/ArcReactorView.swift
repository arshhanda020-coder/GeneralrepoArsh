//
//  ArcReactorView.swift
//  ArshHabitTracker
//
//  A cool steel-blue HUD core — schematic and technical, not a soft glowing
//  toy. Reused as the home screen's centerpiece and Jarvis mode's focal point.
//

import SwiftUI

struct ArcReactorView: View {
    var size: CGFloat = 120
    var isActive: Bool = false

    @State private var rotation: Double = 0
    @State private var pulseUp = false

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.reactorGlow.opacity(isActive ? 0.4 : 0.22), .clear],
                        center: .center,
                        startRadius: size * 0.2,
                        endRadius: size * 0.7
                    )
                )
                .frame(width: size * 1.4, height: size * 1.4)
                .blur(radius: 6)
                .scaleEffect(pulseUp ? 1.04 : 0.97)

            Circle()
                .strokeBorder(Theme.reactorGlow.opacity(0.35), lineWidth: 1)
                .frame(width: size * 0.98, height: size * 0.98)

            // Tick-mark ring — a radar/targeting reticle, not decorative petals.
            ForEach(0..<24, id: \.self) { index in
                let isMajor = index % 6 == 0
                Rectangle()
                    .fill(Theme.reactorCore.opacity(isMajor ? 0.85 : 0.35))
                    .frame(width: 1, height: isMajor ? size * 0.07 : size * 0.03)
                    .offset(y: -size * 0.46)
                    .rotationEffect(.degrees(Double(index) * 15 + rotation))
            }

            Circle()
                .strokeBorder(Theme.reactorGlow.opacity(0.6), lineWidth: 1)
                .frame(width: size * 0.8, height: size * 0.8)
                .rotationEffect(.degrees(-rotation * 0.5))

            Circle()
                .fill(
                    RadialGradient(
                        colors: [.white.opacity(0.95), Theme.reactorCore, Theme.reactorGlow, Theme.reactorDeep],
                        center: .center,
                        startRadius: 1,
                        endRadius: size * 0.48
                    )
                )
                .frame(width: size * 0.56, height: size * 0.56)
                .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 1))
                .shadow(color: Theme.reactorGlow.opacity(isActive ? 0.7 : 0.4), radius: isActive ? 16 : 9)
        }
        .onAppear {
            withAnimation(.linear(duration: 9).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: isActive ? 0.5 : 2.2).repeatForever(autoreverses: true)) {
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

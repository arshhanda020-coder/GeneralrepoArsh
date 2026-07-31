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
            // Sharp instrument glow — small blur radius, no soft bloom.
            Circle()
                .fill(Theme.reactorGlow.opacity(isActive ? 0.5 : 0.3))
                .frame(width: size * 1.1, height: size * 1.1)
                .blur(radius: 3)
                .scaleEffect(pulseUp ? 1.03 : 0.98)

            Circle()
                .strokeBorder(Theme.reactorCore.opacity(0.6), lineWidth: 1)
                .frame(width: size * 0.98, height: size * 0.98)

            // Tick-mark ring — a radar/targeting reticle, not decorative petals.
            ForEach(0..<24, id: \.self) { index in
                let isMajor = index % 6 == 0
                Rectangle()
                    .fill(Theme.reactorCore.opacity(isMajor ? 1 : 0.5))
                    .frame(width: 1, height: isMajor ? size * 0.07 : size * 0.03)
                    .offset(y: -size * 0.46)
                    .rotationEffect(.degrees(Double(index) * 15 + rotation))
            }

            Circle()
                .strokeBorder(Theme.reactorCore.opacity(0.8), lineWidth: 1.2)
                .frame(width: size * 0.8, height: size * 0.8)
                .rotationEffect(.degrees(-rotation * 0.5))

            // Flat, saturated core — a hard disc with a tight specular point,
            // not a soft multi-stop gradient blend.
            Circle()
                .fill(Theme.reactorCore)
                .frame(width: size * 0.56, height: size * 0.56)
                .overlay(
                    Circle()
                        .fill(.white)
                        .frame(width: size * 0.1, height: size * 0.1)
                        .offset(x: -size * 0.12, y: -size * 0.12)
                        .blur(radius: 1)
                )
                .overlay(Circle().stroke(Theme.reactorDeep, lineWidth: 2))
                .shadow(color: Theme.reactorCore.opacity(isActive ? 0.9 : 0.6), radius: isActive ? 14 : 8)
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

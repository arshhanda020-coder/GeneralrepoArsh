//
//  ArcReactorView.swift
//  Odysseus
//
//  A concentric-ring instrument dial — the same shape language as the real
//  JARVIS-clone reference the user pointed to: a rotating dashed outer ring,
//  a tick-mark dial ring turning the other way, and a glowing core that
//  pulses gently at rest and pulses hard (with a small center equalizer) when
//  Odysseus is actually speaking. Clean geometric strokes, not a scribble —
//  every hue reads through Theme (Settings > Appearance).
//

import SwiftUI

/// A ring of short radial tick marks, like a dial or targeting reticle.
private struct TickRing: Shape {
    let count: Int
    let tickFraction: CGFloat

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let tickLength = radius * tickFraction
        for i in 0..<count {
            let angle = Double(i) / Double(count) * 2 * .pi
            let outer = CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            let inner = CGPoint(x: center.x + cos(angle) * (radius - tickLength), y: center.y + sin(angle) * (radius - tickLength))
            path.move(to: outer)
            path.addLine(to: inner)
        }
        return path
    }
}

struct ArcReactorView: View {
    var size: CGFloat = 120
    var isActive: Bool = false
    var isSpeaking: Bool = false

    @State private var pulseUp = false

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
            let intensity = isSpeaking ? 1.0 : (isActive ? 0.85 : 0.6)
            let coreScale: CGFloat = isSpeaking
                ? 1 + CGFloat(abs(sin(t * 10))) * 0.16
                : (pulseUp ? 1.05 : 0.95)

            ZStack {
                // Frosted glass dome — the whole dial sits behind a pane of
                // glass, like it's projected inside a real Stark-tech
                // enclosure rather than floating flat on the background.
                Circle()
                    .fill(.ultraThinMaterial.opacity(0.6))
                    .frame(width: size * 0.98, height: size * 0.98)
                Circle()
                    .fill(Theme.reactorGlow.opacity(0.05))
                    .frame(width: size * 0.98, height: size * 0.98)
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.26), Color.white.opacity(0.06), .clear, .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.plusLighter)
                    .frame(width: size * 0.98, height: size * 0.98)
                // The dome's own curved rim, catching light along the top —
                // separate from the instrument rings inside it.
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [Color.white.opacity(0.55), Theme.reactorGlow.opacity(0.25), Theme.reactorGlow.opacity(0.05)],
                            startPoint: .top, endPoint: .bottom
                        ),
                        lineWidth: 1.2
                    )
                    .frame(width: size * 0.98, height: size * 0.98)

                // Soft ambient glow behind everything.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Theme.reactorGlow.opacity(0.28 * intensity), .clear],
                            center: .center, startRadius: 0, endRadius: size * 0.55
                        )
                    )
                    .frame(width: size, height: size)
                    .blur(radius: size * 0.06)

                // Outer dashed ring, slowly rotating.
                Circle()
                    .stroke(
                        Theme.reactorGlow.opacity(0.55 * intensity),
                        style: StrokeStyle(lineWidth: max(1, size * 0.008), dash: [size * 0.02, size * 0.032])
                    )
                    .frame(width: size * 0.94, height: size * 0.94)
                    .rotationEffect(.degrees(t * (isSpeaking ? 30 : 12)))

                // Tick-mark dial, rotating the opposite way.
                TickRing(count: 44, tickFraction: 0.05)
                    .stroke(Theme.nebulaWispB.opacity(0.4 * intensity), lineWidth: max(1, size * 0.005))
                    .frame(width: size * 0.8, height: size * 0.8)
                    .rotationEffect(.degrees(-t * (isSpeaking ? 22 : 8)))

                // Middle solid ring — the dial's face.
                Circle()
                    .stroke(Theme.nebulaWispB.opacity(0.5 * intensity), lineWidth: max(1, size * 0.014))
                    .frame(width: size * 0.66, height: size * 0.66)

                // A second, faster-counter-rotating dashed ring closer in —
                // gives the dial real depth instead of two flat rings.
                Circle()
                    .stroke(
                        Theme.reactorCore.opacity(0.35 * intensity),
                        style: StrokeStyle(lineWidth: max(1, size * 0.006), dash: [size * 0.01, size * 0.05])
                    )
                    .frame(width: size * 0.54, height: size * 0.54)
                    .rotationEffect(.degrees(t * (isSpeaking ? -40 : -16)))

                // Glowing core.
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [Color.white.opacity(0.95 * intensity), Theme.reactorCore.opacity(0.5 * intensity), .clear],
                            center: .center, startRadius: 0, endRadius: size * 0.24
                        )
                    )
                    .frame(width: size * 0.4, height: size * 0.4)
                    .scaleEffect(coreScale)
                    .shadow(color: Theme.reactorCore, radius: isSpeaking ? 16 : (isActive ? 9 : 5))

                // Center equalizer — flat dots at rest, animated bars when
                // Odysseus is actually speaking (the "listening" mic detail
                // from the reference).
                HStack(spacing: max(1.5, size * 0.016)) {
                    ForEach(0..<5, id: \.self) { i in
                        Capsule()
                            .fill(Color.white.opacity(0.9))
                            .frame(width: max(1.5, size * 0.012), height: barHeight(i, t: t))
                    }
                }
            }
        }
        .frame(width: size, height: size)
        .onAppear {
            withAnimation(.easeInOut(duration: isActive ? 0.7 : 2.4).repeatForever(autoreverses: true)) {
                pulseUp = true
            }
        }
    }

    private func barHeight(_ index: Int, t: Double) -> CGFloat {
        let base = size * 0.035
        guard isSpeaking else { return base }
        let phase = sin(t * 9 + Double(index) * 1.4)
        return base + CGFloat(abs(phase)) * size * 0.11
    }
}

#Preview {
    ZStack {
        Theme.background.ignoresSafeArea()
        ArcReactorView(size: 260, isActive: true)
    }
}

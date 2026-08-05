//
//  MindMapConnectorView.swift
//  ArshHabitTracker
//
//  A beam of light radiating out from the nebula to each node — a curved,
//  organic path (not a geometric right-angle bracket), fading from bright
//  near the core to dim near the node, pulsing on its own cycle through the
//  nebula's wisp colors so it reads as part of the same living cloud.
//

import SwiftUI

struct MindMapConnectorView: View {
    let index: Int
    let start: CGPoint
    let end: CGPoint
    let dotColor: Color
    let hasAppeared: Bool

    @State private var glowUp = false

    private var wispColor: Color {
        [Theme.reactorGlow, Theme.nebulaWispB, Theme.nebulaWispC][index % 3]
    }

    /// A gentle outward bow instead of a straight line — reads as a beam
    /// drifting off the nebula rather than a drafted connector.
    private var beamPath: Path {
        Path { path in
            path.move(to: start)
            let mid = CGPoint(x: (start.x + end.x) / 2, y: (start.y + end.y) / 2)
            let dx = end.x - start.x
            let dy = end.y - start.y
            let length = max(hypot(dx, dy), 1)
            // Perpendicular offset, direction alternates by index for variety.
            let bow: CGFloat = (index % 2 == 0 ? 1 : -1) * length * 0.14
            let control = CGPoint(x: mid.x - dy / length * bow, y: mid.y + dx / length * bow)
            path.addQuadCurve(to: end, control: control)
        }
    }

    var body: some View {
        ZStack {
            beamPath
                .stroke(
                    LinearGradient(
                        colors: [wispColor.opacity(glowUp ? 0.55 : 0.3), wispColor.opacity(0.05)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 5, lineCap: .round)
                )
                .blur(radius: 3)

            beamPath
                .stroke(
                    LinearGradient(
                        colors: [wispColor.opacity(glowUp ? 0.95 : 0.6), wispColor.opacity(0.15)],
                        startPoint: .leading, endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 1.2, lineCap: .round)
                )
        }
        .opacity(hasAppeared ? 1 : 0)
        .animation(.easeIn(duration: 0.4).delay(Double(index) * 0.06), value: hasAppeared)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true).delay(Double(index) * 0.15)) {
                glowUp = true
            }
        }
    }
}

//
//  MindMapConnectorView.swift
//  ArshHabitTracker
//
//  The "bracket" that links a node back to the center — a soft glowing
//  thread that pulses on its own cycle, cycling through the nebula's wisp
//  colors so the connectors read as part of the same living cloud as the
//  reactor itself.
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

    private var bends: [CGPoint] {
        guard abs(end.y - start.y) >= 1, abs(end.x - start.x) >= 1 else { return [] }
        let midX = (start.x + end.x) / 2
        return [CGPoint(x: midX, y: start.y), CGPoint(x: midX, y: end.y)]
    }

    /// Right-angle "elbow" routing: horizontal, vertical, horizontal — reads as a
    /// workflow-diagram connector rather than a straight mind-map spoke.
    private var path: Path {
        Path { path in
            path.move(to: start)
            if abs(end.y - start.y) < 1 || abs(end.x - start.x) < 1 {
                path.addLine(to: end)
                return
            }
            let midX = (start.x + end.x) / 2
            path.addLine(to: CGPoint(x: midX, y: start.y))
            path.addLine(to: CGPoint(x: midX, y: end.y))
            path.addLine(to: end)
        }
    }

    var body: some View {
        ZStack {
            path
                .stroke(wispColor.opacity(glowUp ? 0.32 : 0.14), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .blur(radius: 2)

            path
                .stroke(wispColor.opacity(glowUp ? 0.85 : 0.55), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))

            ForEach(Array(bends.enumerated()), id: \.offset) { _, point in
                Circle()
                    .fill(dotColor.opacity(0.6))
                    .frame(width: 5, height: 5)
                    .position(point)
            }
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

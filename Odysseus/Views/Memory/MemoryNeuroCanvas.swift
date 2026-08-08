//
//  MemoryNeuroCanvas.swift
//  Odysseus
//
//  A small nebula/neural-network visualization of the memory brain — each
//  memory is a glowing node, connected to its nearest neighbors like
//  synapses, scattered inside a soft violet nebula haze. Purely visual;
//  tap a node to open it, tap the canvas background to add a new one.
//

import SwiftUI

struct MemoryNeuroCanvas: View {
    let entries: [MemoryEntry]
    var onSelect: (MemoryEntry) -> Void

    private let size: CGFloat = 260

    private struct Node {
        let entry: MemoryEntry
        let point: CGPoint
    }

    private var nodes: [Node] {
        let center = size / 2
        return entries.map { entry in
            // Deterministic pseudo-random layout from the entry's stable id,
            // so nodes don't jump around on every re-render.
            var generator = SeededGenerator(seed: entry.id.hashValue)
            let angle = Double.random(in: 0..<360, using: &generator)
            let radiusFraction = Double.random(in: 0.28...0.92, using: &generator)
            let radius = center * radiusFraction
            let point = CGPoint(
                x: center + cos(angle * .pi / 180) * radius,
                y: center + sin(angle * .pi / 180) * radius
            )
            return Node(entry: entry, point: point)
        }
    }

    var body: some View {
        ZStack {
            haze

            Canvas { context, canvasSize in
                let items = nodes
                for i in items.indices {
                    for j in items.indices where j > i {
                        let a = items[i].point
                        let b = items[j].point
                        let distance = hypot(a.x - b.x, a.y - b.y)
                        guard distance < canvasSize.width * 0.42 else { continue }
                        var path = Path()
                        path.move(to: a)
                        path.addLine(to: b)
                        let opacity = 0.35 * (1 - distance / (canvasSize.width * 0.42))
                        context.stroke(path, with: .color(Theme.reactorGlow.opacity(opacity)), lineWidth: 1)
                    }
                }
            }
            .frame(width: size, height: size)

            ForEach(nodes.indices, id: \.self) { index in
                let node = nodes[index]
                Button {
                    onSelect(node.entry)
                } label: {
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [.white, Theme.reactorCore, .clear],
                                center: .center, startRadius: 0, endRadius: 10
                            )
                        )
                        .frame(width: node.entry.isAISaved ? 12 : 9, height: node.entry.isAISaved ? 12 : 9)
                        .shadow(color: Theme.reactorCore.opacity(0.8), radius: 5)
                }
                .buttonStyle(.plain)
                .position(node.point)
            }
        }
        .frame(width: size, height: size)
        .background(
            Circle()
                .fill(Theme.reactorDeep.opacity(0.06))
        )
    }

    private var haze: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [Theme.reactorGlow.opacity(0.18), .clear], center: .center, startRadius: 0, endRadius: size * 0.55))
            Circle()
                .fill(RadialGradient(colors: [Theme.reactorAccentB.opacity(0.12), .clear], center: UnitPoint(x: 0.35, y: 0.4), startRadius: 0, endRadius: size * 0.4))
        }
        .frame(width: size, height: size)
    }
}

/// Deterministic RNG so each memory's node position is stable across
/// re-renders instead of reshuffling every time SwiftUI redraws.
private struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64

    init(seed: Int) {
        state = UInt64(bitPattern: Int64(seed)) &+ 0x9E3779B97F4A7C15
    }

    mutating func next() -> UInt64 {
        state ^= state << 13
        state ^= state >> 7
        state ^= state << 17
        return state
    }
}

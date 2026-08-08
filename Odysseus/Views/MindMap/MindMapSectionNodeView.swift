//
//  MindMapSectionNodeView.swift
//  Odysseus
//
//  One mind-map node — gently hovers in place (its own independent phase, so
//  the whole map doesn't bob in lockstep), themed around the nebula.
//

import SwiftUI

struct MindMapSectionNodeView: View {
    let section: MindMapSection
    let index: Int
    let badge: String?
    let width: CGFloat
    let height: CGFloat
    let hasAppeared: Bool

    @State private var hoverUp = false

    private var hoverDelay: Double { Double(index) * 0.18 }
    private var hoverDistance: CGFloat { 3 + CGFloat(index % 3) }

    var body: some View {
        NavigationLink(value: section) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(section.accentColor.opacity(0.14))
                        .frame(width: 30, height: 30)
                    Image(systemName: section.symbolName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(section.accentColor)
                }
                Text(section.shortTitle.uppercased())
                    .font(.system(.caption2, design: .monospaced).weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(Theme.primaryText)
                if let badge {
                    Text(badge)
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundStyle(section.accentColor)
                }
            }
            .frame(width: width, height: height)
            .glassPanel(
                cornerRadius: 6,
                tintOpacity: 0.35,
                borderColor: section.accentColor,
                borderOpacity: 0.7,
                glow: section.accentColor,
                glowRadius: 5
            )
        }
        .buttonStyle(.plain)
        .offset(y: hoverUp ? -hoverDistance : hoverDistance)
        .scaleEffect(hasAppeared ? 1 : 0.15)
        .opacity(hasAppeared ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.68).delay(Double(index) * 0.06), value: hasAppeared)
        .onAppear {
            withAnimation(.easeInOut(duration: 2.6).repeatForever(autoreverses: true).delay(hoverDelay)) {
                hoverUp = true
            }
        }
    }
}

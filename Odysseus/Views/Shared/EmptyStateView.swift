//
//  EmptyStateView.swift
//  Odysseus
//
//  The "nothing here yet" state for a list/section — a tinted icon badge,
//  a short headline, and a one-line hint, replacing what used to be a
//  single line of gray caption text scattered across ~a dozen screens.
//  Tinted with the section's own accent color (MindMapSection.accentColor)
//  so it still reads as part of the same list once real content shows up,
//  not a separate "error-ish" state. Matches GlassPanel's own rule: a
//  soft tint fill behind the icon, no glow, no gradient.
//

import SwiftUI

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String? = nil
    var tint: Color = Theme.dimText

    @State private var appeared = false

    var body: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.15))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
            }

            VStack(spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.primaryText)
                if let message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Theme.dimText)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 26)
        .padding(.horizontal, 28)
        .scaleEffect(appeared ? 1 : 0.92)
        .opacity(appeared ? 1 : 0)
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                appeared = true
            }
        }
    }
}

#Preview {
    EmptyStateView(
        icon: MindMapSection.projects.symbolName,
        title: "No projects yet",
        message: "Tap + to add one.",
        tint: MindMapSection.projects.accentColor
    )
    .glassPanel(cornerRadius: 14)
    .padding()
    .background(Theme.background)
}

//
//  HUDStatusPanel.swift
//  Odysseus
//
//  A small bracketed panel of label/value readouts — the stat/status boxes
//  flanking the reactor in both the home screen and Odysseus mode. Shared so
//  both look identical rather than two similar-but-different components.
//

import SwiftUI

struct HUDStatusRow: Identifiable {
    let id = UUID()
    let label: String
    let value: String
    let isLive: Bool

    init(_ label: String, _ value: String, isLive: Bool = true) {
        self.label = label
        self.value = value
        self.isLive = isLive
    }
}

struct HUDStatusPanel: View {
    let title: String
    let rows: [HUDStatusRow]
    var width: CGFloat = 84
    /// When true, each row is tappable and calls `onSelect` with its index —
    /// used when a panel doubles as the app's section navigation list.
    var onSelect: ((Int) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title)
                .font(.system(size: 10, design: .monospaced).weight(.bold))
                .tracking(1.5)
                .foregroundStyle(Theme.dimText)
            Rectangle()
                .fill(Theme.cardBorder)
                .frame(height: 1)
                .padding(.bottom, 1)
            ForEach(Array(rows.enumerated()), id: \.element.id) { index, row in
                rowView(row, index: index)
            }
        }
        .padding(10)
        .frame(width: width, alignment: .leading)
        .glassPanel(
            cornerRadius: 6,
            tintOpacity: 0.55,
            borderColor: Theme.reactorGlow,
            borderOpacity: 0.4,
            glow: Theme.reactorGlow,
            glowRadius: 5
        )
    }

    @ViewBuilder
    private func rowView(_ row: HUDStatusRow, index: Int) -> some View {
        let content = HStack(spacing: 5) {
            Text(row.label)
                .font(.system(size: 10, design: .monospaced))
                .foregroundStyle(Theme.dimText)
                .lineLimit(1)
            Spacer(minLength: 4)
            Text(row.value)
                .font(.system(size: 10, design: .monospaced).weight(.semibold))
                .foregroundStyle(row.isLive ? Theme.terminalGreen : Theme.dimText)
                .lineLimit(1)
            Circle()
                .fill(row.isLive ? Theme.terminalGreen : Theme.dimText.opacity(0.5))
                .frame(width: 3.5, height: 3.5)
        }
        if let onSelect {
            Button { onSelect(index) } label: { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}

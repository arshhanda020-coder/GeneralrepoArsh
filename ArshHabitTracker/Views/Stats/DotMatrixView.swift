//
//  DotMatrixView.swift
//  ArshHabitTracker
//

import SwiftUI

struct DotMatrixView: View {
    let records: [HabitDayRecord]
    let accentColor: Color

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(records) { record in
                Circle()
                    .fill(fillColor(for: record))
                    .frame(height: 12)
                    .overlay(
                        Circle().stroke(
                            record.scheduled && !record.completed ? Theme.cardBorder : .clear,
                            lineWidth: 1.5
                        )
                    )
            }
        }
    }

    private func fillColor(for record: HabitDayRecord) -> Color {
        if record.completed { return accentColor }
        if record.scheduled { return .clear }
        return Theme.cardBorder.opacity(0.4)
    }
}

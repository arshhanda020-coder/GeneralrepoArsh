//
//  WeeklySummaryView.swift
//  Odysseus
//
//  "How am I doing this week" at a glance: total consumed/burned over the
//  trailing 7 days, the weight change over that window, and a day-by-day
//  breakdown — purely presentational, FoodContentView owns the math.
//

import SwiftUI

/// One day's calorie in/out, oldest-to-newest across the trailing 7-day window.
struct DayCalorieSummary: Identifiable {
    let date: Date
    let consumed: Int
    let burned: Int

    var id: Date { date }
    var net: Int { consumed - burned }
}

struct WeeklySummaryView: View {
    let days: [DayCalorieSummary]
    /// End-of-week weight minus start-of-week weight — negative means lost.
    let weightChangeLbs: Double?

    private var totalConsumed: Int { days.map(\.consumed).reduce(0, +) }
    private var totalBurned: Int { days.map(\.burned).reduce(0, +) }
    private var maxDailyValue: Int { max(days.map { max($0.consumed, $0.burned) }.max() ?? 0, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("THIS WEEK")
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.5)
                .foregroundStyle(Theme.dimText)

            VStack(spacing: 14) {
                HStack(spacing: 10) {
                    bigStat(label: "CONSUMED", value: "\(totalConsumed)", unit: "cal", color: MindMapSection.health.accentColor)
                    bigStat(label: "BURNED", value: "\(totalBurned)", unit: "cal", color: Theme.terminalAmber)
                    bigStat(
                        label: "WEIGHT",
                        value: weightChangeLbs.map { String(format: "%+.1f", $0) } ?? "—",
                        unit: weightChangeLbs == nil ? "no data" : "lbs",
                        color: weightColor
                    )
                }

                VStack(spacing: 6) {
                    ForEach(days) { day in
                        dayRow(day)
                    }
                }
            }
            .padding(12)
            .glassPanel(cornerRadius: 10)
        }
    }

    private var weightColor: Color {
        guard let weightChangeLbs else { return Theme.dimText }
        return weightChangeLbs <= 0 ? Theme.terminalGreen : Theme.terminalAmber
    }

    private func bigStat(label: String, value: String, unit: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(.caption2, design: .monospaced).weight(.bold))
                .tracking(0.3)
                .foregroundStyle(Theme.dimText)
            Text(value)
                .font(.system(.title3, design: .monospaced).weight(.bold))
                .foregroundStyle(color)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(unit)
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func dayRow(_ day: DayCalorieSummary) -> some View {
        HStack(spacing: 8) {
            Text(day.date.formatted(.dateTime.weekday(.abbreviated)))
                .font(.caption2.weight(.semibold))
                .foregroundStyle(Theme.primaryText)
                .frame(width: 32, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.cardBorder.opacity(0.3))
                    Capsule()
                        .fill(MindMapSection.health.accentColor.opacity(0.7))
                        .frame(width: geo.size.width * (CGFloat(day.consumed) / CGFloat(maxDailyValue)))
                }
            }
            .frame(height: 6)

            Text(day.consumed > 0 || day.burned > 0 ? "\(day.consumed)-\(day.burned)" : "—")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.dimText)
                .frame(width: 70, alignment: .trailing)
        }
    }
}

#Preview {
    WeeklySummaryView(
        days: (0..<7).map { offset in
            DayCalorieSummary(
                date: Calendar.current.date(byAdding: .day, value: -6 + offset, to: .now) ?? .now,
                consumed: Int.random(in: 1500...2000),
                burned: Int.random(in: 200...800)
            )
        },
        weightChangeLbs: -1.4
    )
    .padding()
    .background(Theme.background)
}

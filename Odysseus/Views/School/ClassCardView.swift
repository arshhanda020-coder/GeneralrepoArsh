//
//  ClassCardView.swift
//  Odysseus
//
//  Google Classroom-style class tile: a colored banner (name + icon) over a
//  matte footer with the at-a-glance pending count. Used in the School
//  screen's card grid.
//

import SwiftUI

struct ClassCardView: View {
    let schoolClass: SchoolClass
    var isDropped: Bool = false

    private var pendingCount: Int {
        schoolClass.topics.flatMap(\.assignments).filter { !$0.isDone }.count
    }

    private var statusText: String {
        if schoolClass.topics.isEmpty { return "No topics yet" }
        return pendingCount == 0 ? "All caught up" : "\(pendingCount) pending"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            banner
            footer
        }
        .background(Theme.card.opacity(0.92))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cardBorder.opacity(0.9), lineWidth: 1))
        .opacity(isDropped ? 0.55 : 1)
    }

    private var banner: some View {
        ZStack(alignment: .bottomLeading) {
            schoolClass.bannerColor.gradient

            Image(systemName: "graduationcap.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white.opacity(0.18))
                .padding(10)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)

            Text(schoolClass.name)
                .font(.headline.weight(.bold))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(10)
                .shadow(color: .black.opacity(0.25), radius: 2, y: 1)
        }
        .frame(height: 86)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 14, bottomLeadingRadius: 0, bottomTrailingRadius: 0, topTrailingRadius: 14, style: .continuous))
    }

    private var footer: some View {
        HStack {
            Circle()
                .fill(pendingCount == 0 ? Theme.terminalGreen : schoolClass.bannerColor.base)
                .frame(width: 6, height: 6)
            Text(statusText)
                .font(.caption2.weight(.medium))
                .foregroundStyle(Theme.dimText)
                .lineLimit(1)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundStyle(Theme.dimText)
        }
        .padding(10)
    }
}

#Preview {
    ClassCardView(schoolClass: SchoolClass(name: "AP Computer Science"))
        .frame(width: 170)
        .padding()
        .background(Theme.background)
}

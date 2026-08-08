//
//  ComingSoonView.swift
//  Odysseus
//
//  Placeholder for sections that are iOS-only for now (HealthKit, the Gmail
//  OAuth flow, and similar iPhone-tied integrations don't have a Mac-side
//  equivalent yet). Keeps the Mac target's section grid fully navigable
//  instead of silently omitting entries.
//

import SwiftUI

struct ComingSoonView: View {
    let title: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "macbook.and.iphone")
                .font(.system(size: 34))
                .foregroundStyle(Theme.dimText)
            Text("\(title) is on iPhone/iPad for now")
                .font(.headline)
                .foregroundStyle(Theme.primaryText)
            Text("This section depends on an iOS-only integration and hasn't made it to the Mac build yet.")
                .font(.subheadline)
                .foregroundStyle(Theme.dimText)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(title)
    }
}

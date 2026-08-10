//
//  OdysseusOverlay.swift
//  Odysseus
//
//  Mounted once at the app root (above the NavigationStack) purely to host
//  Odysseus's full-screen takeover — it draws nothing itself. Settings and the
//  Odysseus entry point live as normal, non-floating controls on the home
//  screen's top row instead of a persistent overlay on every screen.
//

import SwiftUI

struct OdysseusOverlay: View {
    @EnvironmentObject private var odysseus: OdysseusController

    var body: some View {
        Color.clear
            // Color.clear is still hit-testable in SwiftUI by default — left
            // as-is, this full-screen layer sits directly on top of
            // ContentView in RootView's ZStack and silently swallows every
            // tap/click app-wide (buttons, list rows, sheet controls like
            // "Add Google Account" in Notes or "Delete project") whenever
            // Odysseus isn't expanded. It draws nothing and exists only to
            // host the full-screen-cover modifier, so it must never
            // intercept touches itself.
            .allowsHitTesting(false)
            .platformFullScreenCover(isPresented: $odysseus.isExpanded) {
                OdysseusTerminalView()
            }
    }
}

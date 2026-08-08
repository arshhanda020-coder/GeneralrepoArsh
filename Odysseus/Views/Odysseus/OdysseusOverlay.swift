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
            .platformFullScreenCover(isPresented: $odysseus.isExpanded) {
                OdysseusTerminalView()
            }
    }
}

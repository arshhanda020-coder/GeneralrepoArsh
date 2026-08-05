//
//  JarvisOverlay.swift
//  ArshHabitTracker
//
//  Mounted once at the app root (above the NavigationStack) purely to host
//  Jarvis's full-screen takeover — it draws nothing itself. Settings and the
//  Jarvis entry point live as normal, non-floating controls on the home
//  screen's top row instead of a persistent overlay on every screen.
//

import SwiftUI

struct JarvisOverlay: View {
    @EnvironmentObject private var jarvis: JarvisController

    var body: some View {
        Color.clear
            .fullScreenCover(isPresented: $jarvis.isExpanded) {
                JarvisTerminalView()
            }
    }
}

//
//  RootView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var odysseus = OdysseusController.shared
    @State private var showingWritingSample = !WritingProfile.hasAnswered
    @State private var isUnlocked = false

    var body: some View {
        Group {
            if isUnlocked {
                ZStack {
                    ContentView()
                    OdysseusOverlay()
                }
                .environmentObject(odysseus)
                .onAppear {
                    odysseus.configure(modelContext: modelContext)
                    odysseus.refreshDailySuggestion()
                    odysseus.runNotificationChecks()
                }
                .platformFullScreenCover(isPresented: $showingWritingSample) {
                    WritingSampleView(isOnboarding: true)
                }
            } else {
                AppLockView(onUnlocked: { isUnlocked = true })
            }
        }
        // Every screen uses fixed-size custom layouts (badges, icon frames,
        // the reactor) that were never designed to accommodate iOS's
        // accessibility text-size scaling — if the device (or an
        // iCloud-synced accessibility setting) has a larger text size on,
        // every screen blows up/overlaps in a way that reads as "zoomed in."
        // Locking the whole app to the standard size removes that variable
        // entirely regardless of the device's Settings.
        .dynamicTypeSize(.large)
        // The HUD corner-bracket frame, applied once here so every screen in
        // the app gets it — matches the reference command-console look
        // app-wide instead of needing every individual screen rebuilt.
        .hudFramed()
    }
}

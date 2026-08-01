//
//  RootView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var jarvis = JarvisController.shared
    @State private var showingWritingSample = !WritingProfile.hasAnswered
    @State private var isUnlocked = false

    var body: some View {
        Group {
            if isUnlocked {
                ZStack {
                    ContentView()
                    JarvisOverlay()
                }
                .environmentObject(jarvis)
                .onAppear {
                    jarvis.configure(modelContext: modelContext)
                    jarvis.refreshDailySuggestion()
                }
                .fullScreenCover(isPresented: $showingWritingSample) {
                    WritingSampleView(isOnboarding: true)
                }
            } else {
                AppLockView(onUnlocked: { isUnlocked = true })
            }
        }
    }
}

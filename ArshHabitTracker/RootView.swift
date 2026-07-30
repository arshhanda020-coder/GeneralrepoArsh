//
//  RootView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var jarvis = JarvisController.shared

    var body: some View {
        ZStack {
            ContentView()
            JarvisOverlay()
        }
        .environmentObject(jarvis)
        .onAppear {
            jarvis.configure(modelContext: modelContext)
            jarvis.refreshDailySuggestion()
        }
    }
}

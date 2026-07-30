//
//  JarvisOverlay.swift
//  ArshHabitTracker
//
//  Floating orb mounted once at the app root (above the NavigationStack) so
//  it persists across every screen. Tapping it activates/reopens Jarvis mode.
//

import SwiftUI

struct JarvisOverlay: View {
    @EnvironmentObject private var jarvis: JarvisController

    var body: some View {
        VStack {
            Spacer()
            HStack {
                Spacer()
                Button {
                    jarvis.activate()
                } label: {
                    ArcReactorView(size: 56, isActive: jarvis.isActive)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 20)
                .padding(.bottom, 24)
                .accessibilityLabel("Jarvis")
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $jarvis.isExpanded) {
            JarvisTerminalView()
        }
    }
}

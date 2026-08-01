//
//  JarvisOverlay.swift
//  ArshHabitTracker
//
//  Floating chrome mounted once at the app root (above the NavigationStack)
//  so it persists across every screen: Settings up top, Jarvis's orb just
//  below it, tucked into the top-trailing corner. Search lives as a real
//  search bar on the home screen instead of living here.
//

import SwiftUI

struct JarvisOverlay: View {
    @EnvironmentObject private var jarvis: JarvisController
    @State private var showingSettings = false

    var body: some View {
        VStack {
            HStack {
                Spacer()
                VStack(spacing: 14) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .font(.body)
                            .foregroundStyle(Theme.dimText)
                            .frame(width: 32, height: 32)
                            .background(Theme.card)
                            .clipShape(Circle())
                            .overlay(Circle().stroke(Theme.cardBorder, lineWidth: 1))
                    }
                    .accessibilityLabel("Settings")

                    Button {
                        jarvis.activate()
                    } label: {
                        ArcReactorView(size: 48, isActive: jarvis.isActive)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Jarvis")
                }
                .padding(.trailing, 16)
                .padding(.top, 8)
            }
            Spacer()
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .fullScreenCover(isPresented: $jarvis.isExpanded) {
            JarvisTerminalView()
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
    }
}

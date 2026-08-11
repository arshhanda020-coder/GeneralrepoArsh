//
//  AppearanceSettingsView.swift
//  Odysseus
//
//  Every color token is individually recolorable. Defaults are the calm,
//  matte palette, and follow the system's light/dark setting; a color set
//  here applies in both. Sections used to each get their own accent — now
//  they all share the one "Signature Accent" token below, so there's no
//  separate per-section list anymore.
//

import SwiftUI

struct AppearanceSettingsView: View {
    @State private var refreshTick = 0

    var body: some View {
        Form {
            Section("Global") {
                ForEach(ThemeToken.allCases) { token in
                    ColorPicker(token.displayName, selection: tokenBinding(token))
                }
            }

            Section {
                Button("Reset all colors to defaults", role: .destructive) {
                    ThemeColorSettings.resetAll()
                    refreshTick += 1
                }
            }
        }
        .navigationTitle("Colors")
        .inlineNavigationTitle()
        .id(refreshTick)
    }

    private func tokenBinding(_ token: ThemeToken) -> Binding<Color> {
        Binding(
            get: { Color(token: token) },
            set: { ThemeColorSettings.setHex($0.hexString, for: token) }
        )
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}

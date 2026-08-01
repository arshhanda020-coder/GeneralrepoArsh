//
//  AppearanceSettingsView.swift
//  ArshHabitTracker
//
//  Every color token, mind-map section, and habit category is individually
//  recolorable. Defaults are the muted, professional palette.
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

            Section("Mind Map Sections") {
                ForEach(MindMapSection.allCases) { section in
                    ColorPicker(section.title, selection: sectionBinding(section))
                }
            }

            Section("Habit Categories") {
                ForEach(HabitCategory.allCases) { category in
                    ColorPicker(category.displayName, selection: categoryBinding(category))
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
        .navigationBarTitleDisplayMode(.inline)
        .id(refreshTick)
    }

    private func tokenBinding(_ token: ThemeToken) -> Binding<Color> {
        Binding(
            get: { Color(hex: ThemeColorSettings.hex(for: token)) },
            set: { ThemeColorSettings.setHex($0.hexString, for: token) }
        )
    }

    private func sectionBinding(_ section: MindMapSection) -> Binding<Color> {
        Binding(
            get: { Color(hex: ThemeColorSettings.sectionHex(for: section)) },
            set: { ThemeColorSettings.setSectionHex($0.hexString, for: section) }
        )
    }

    private func categoryBinding(_ category: HabitCategory) -> Binding<Color> {
        Binding(
            get: { Color(hex: ThemeColorSettings.categoryHex(for: category)) },
            set: { ThemeColorSettings.setCategoryHex($0.hexString, for: category) }
        )
    }
}

#Preview {
    NavigationStack {
        AppearanceSettingsView()
    }
}

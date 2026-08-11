//
//  ClassColorPickerSheet.swift
//  Odysseus
//
//  Classroom-style "customize" swatch grid — tap a color to theme a class's
//  banner. Shared by the class card grid's Manage sheet and the class
//  detail header, so picking a color reads the same everywhere.
//

import SwiftUI
import SwiftData

struct ClassColorPickerSheet: View {
    @Bindable var schoolClass: SchoolClass
    @Environment(\.dismiss) private var dismiss

    private let columns = [GridItem(.adaptive(minimum: 64, maximum: 80), spacing: 14)]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 14) {
                    ForEach(ClassBannerColor.allCases) { color in
                        swatch(color)
                    }
                }
                .padding(20)
            }
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Banner color")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func swatch(_ color: ClassBannerColor) -> some View {
        let isSelected = schoolClass.bannerColor == color
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                schoolClass.colorIndex = color.rawValue
            }
        } label: {
            VStack(spacing: 6) {
                Circle()
                    .fill(color.gradient)
                    .frame(width: 44, height: 44)
                    .overlay(
                        Image(systemName: "checkmark")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.white)
                            .opacity(isSelected ? 1 : 0)
                    )
                    .overlay(
                        Circle().stroke(Theme.primaryText.opacity(isSelected ? 0.6 : 0), lineWidth: 2)
                            .padding(-3)
                    )
                Text(color.displayName)
                    .font(.caption2)
                    .foregroundStyle(Theme.dimText)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ClassColorPickerSheet(schoolClass: SchoolClass(name: "AP Biology"))
        .modelContainer(for: [SchoolClass.self], inMemory: true)
}

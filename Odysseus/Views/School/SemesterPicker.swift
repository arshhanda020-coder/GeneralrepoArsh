//
//  SemesterPicker.swift
//  Odysseus
//
//  Dropped at the top of every School screen that shows graded work — GPA,
//  a class's topics/assignments/material — so switching semesters here
//  scopes all of them consistently. Summer Work is deliberately unaffected
//  by this (it isn't part of either semester).
//

import SwiftUI

struct SemesterPicker: View {
    @Binding var selection: SchoolTerm

    var body: some View {
        Picker("Semester", selection: $selection) {
            ForEach(SchoolTerm.allCases) { term in
                Text(term.displayName).tag(term)
            }
        }
        .pickerStyle(.segmented)
    }
}

/// Reads/writes the shared SchoolTermSettings so every screen that drops
/// this in stays in sync without threading a binding through navigation.
struct SharedSemesterPicker: View {
    @State private var selection: SchoolTerm = SchoolTermSettings.selected

    var body: some View {
        SemesterPicker(selection: $selection)
            .onChange(of: selection) { _, newValue in
                SchoolTermSettings.selected = newValue
            }
    }
}

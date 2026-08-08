//
//  WritingSampleView.swift
//  Odysseus
//
//  Collects one real writing sample so AI drafting across the app (emails,
//  extracurricular descriptions, etc.) matches the user's actual voice
//  instead of sounding generic. Shown once on first launch, and reachable
//  again from AI Settings if they want to redo it.
//

import SwiftUI

struct WritingSampleView: View {
    @Environment(\.dismiss) private var dismiss
    var isOnboarding: Bool = false

    @State private var text: String = WritingProfile.sample ?? ""

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(WritingProfile.prompt)
                    .font(.subheadline)
                    .foregroundStyle(Theme.dimText)

                TextEditor(text: $text)
                    .frame(minHeight: 160)
                    .padding(8)
                    .glassPanel(cornerRadius: 10)

                Spacer()

                Button {
                    WritingProfile.save(text)
                    dismiss()
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)

                if isOnboarding {
                    Button("Skip for now") {
                        WritingProfile.save("")
                        dismiss()
                    }
                    .font(.caption)
                    .foregroundStyle(Theme.dimText)
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(16)
            .background(Theme.background.ignoresSafeArea())
            .navigationTitle("Your Writing Style")
            .inlineNavigationTitle()
            .toolbar {
                if !isOnboarding {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
            }
        }
        .interactiveDismissDisabled(isOnboarding)
    }
}

#Preview {
    WritingSampleView()
}

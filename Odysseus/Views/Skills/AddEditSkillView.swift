//
//  AddEditSkillView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct AddEditSkillView: View {
    let skill: Skill?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "✨"
    @State private var colorHex = "5B8CFF"
    @State private var description = ""
    @State private var targetSessions = 10

    private let emojiOptions = ["✨", "📊", "🐍", "🎤", "📈", "⌨️", "🎨", "🎵", "🧠", "💡", "🏆", "🧩", "🗣️", "🛠️", "📚"]
    private let colorOptions = ["5B8CFF", "FF6B6B", "FFB84D", "FF8FD1", "4ADE80", "A78BFA", "38BDF8", "F472B6"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Skill") {
                    TextField("Name", text: $name)
                    Picker("Emoji", selection: $emoji) {
                        ForEach(emojiOptions, id: \.self) { option in
                            Text(option).tag(option)
                        }
                    }
                    .pickerStyle(.menu)
                    colorPicker
                }

                Section("Description") {
                    TextField("What are you learning?", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Target sessions") {
                    Stepper("\(targetSessions) sessions", value: $targetSessions, in: 1...200)
                }

                if skill != nil {
                    Section {
                        Button("Delete skill", role: .destructive) { deleteSkill() }
                    }
                }
            }
            .navigationTitle(skill == nil ? "New Skill" : "Edit Skill")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: populateIfEditing)
            .onSubmit {
                guard !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                save()
            }
        }
    }

    private var colorPicker: some View {
        HStack {
            Text("Color")
            Spacer()
            ForEach(colorOptions, id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(.white, lineWidth: colorHex == hex ? 2 : 0))
                    .onTapGesture { colorHex = hex }
            }
        }
    }

    private func populateIfEditing() {
        guard let skill else { return }
        name = skill.name
        emoji = skill.emoji
        colorHex = skill.colorHex
        description = skill.skillDescription
        targetSessions = skill.targetSessions
    }

    private func save() {
        if let skill {
            skill.name = name
            skill.emoji = emoji
            skill.colorHex = colorHex
            skill.skillDescription = description
            skill.targetSessions = targetSessions
        } else {
            let newSkill = Skill(
                name: name,
                emoji: emoji,
                colorHex: colorHex,
                skillDescription: description,
                targetSessions: targetSessions
            )
            modelContext.insert(newSkill)
        }
        dismiss()
    }

    private func deleteSkill() {
        if let skill {
            modelContext.delete(skill)
        }
        dismiss()
    }
}

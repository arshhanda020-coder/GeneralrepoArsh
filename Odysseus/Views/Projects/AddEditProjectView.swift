//
//  AddEditProjectView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct AddEditProjectView: View {
    let project: Project?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "🛠️"
    @State private var colorHex = "5B8CFF"
    @State private var description = ""
    @State private var status: ProjectStatus = .building
    @State private var hasTargetDate = false
    @State private var targetDate = Date()

    private let emojiOptions = ["🛠️", "🚀", "💻", "📱", "🧾", "💰", "🚛", "🤖", "🧠", "📊", "🗂️", "⚙️"]
    private let colorOptions = ["5FB8A8", "D9695F", "D9A857", "5FCB8C", "4F8FA8", "8A7CA8", "6B8F5A", "C77DAE"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Project") {
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
                    TextField("What is this project?", text: $description, axis: .vertical)
                        .lineLimit(2...5)
                }

                Section("Status") {
                    Picker("Status", selection: $status) {
                        ForEach(ProjectStatus.allCases) { option in
                            Text(option.displayName).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Target Completion") {
                    Toggle("Set a target date", isOn: $hasTargetDate)
                    if hasTargetDate {
                        DatePicker("Done by", selection: $targetDate, displayedComponents: .date)
                    } else {
                        Text("Set this so the project shows up on the Calendar.")
                            .font(.caption)
                            .foregroundStyle(Theme.dimText)
                    }
                }

                if project != nil {
                    Section {
                        Button("Delete project", role: .destructive) { deleteProject() }
                    }
                }
            }
            .navigationTitle(project == nil ? "New Project" : "Edit Project")
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
        guard let project else { return }
        name = project.name
        emoji = project.emoji
        colorHex = project.colorHex
        description = project.projectDescription
        status = project.status
        if let target = project.targetDate {
            hasTargetDate = true
            targetDate = target
        } else {
            hasTargetDate = false
        }
    }

    private func save() {
        if let project {
            project.name = name
            project.emoji = emoji
            project.colorHex = colorHex
            project.projectDescription = description
            project.status = status
            project.targetDate = hasTargetDate ? targetDate : nil
        } else {
            let newProject = Project(
                name: name,
                emoji: emoji,
                colorHex: colorHex,
                projectDescription: description,
                status: status,
                targetDate: hasTargetDate ? targetDate : nil
            )
            modelContext.insert(newProject)
        }
        dismiss()
    }

    private func deleteProject() {
        if let project {
            modelContext.delete(project)
        }
        dismiss()
    }
}

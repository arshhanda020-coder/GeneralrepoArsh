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
    @State private var repoURLString = ""

    /// Hardcoded for now — the GitHub repo the user has saved for quick linking.
    /// TODO: replace with a real "pick a repo" flow (search/list the user's GitHub repos).
    private static let savedRepoURL = "https://github.com/ruvnet/ruflo"

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

                Section("Repo") {
                    TextField("https://github.com/owner/repo", text: $repoURLString)
                        #if os(iOS)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        #endif
                        .autocorrectionDisabled()
                    if repoURLString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Use saved repo") {
                            repoURLString = Self.savedRepoURL
                        }
                        .font(.caption.weight(.semibold))
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
        repoURLString = project.repoURLString ?? ""
    }

    private func save() {
        let trimmedRepoURL = repoURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        if let project {
            project.name = name
            project.emoji = emoji
            project.colorHex = colorHex
            project.projectDescription = description
            project.status = status
            project.repoURLString = trimmedRepoURL.isEmpty ? nil : trimmedRepoURL
        } else {
            let newProject = Project(
                name: name,
                emoji: emoji,
                colorHex: colorHex,
                projectDescription: description,
                status: status,
                repoURLString: trimmedRepoURL.isEmpty ? nil : trimmedRepoURL
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

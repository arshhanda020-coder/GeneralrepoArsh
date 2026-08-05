//
//  AddEditExtracurricularView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData
import PhotosUI

struct AddEditExtracurricularView: View {
    let item: Extracurricular?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var activityDescription = ""
    @State private var category = ""
    @State private var collaborators = ""
    @State private var selectedProof: PhotosPickerItem?
    @State private var proofData: Data?

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Title", text: $title)
                    TextField("Category (optional)", text: $category)
                    TextField("Who with (optional)", text: $collaborators)
                }
                Section("Description") {
                    TextField("What it is, what you did, why it matters", text: $activityDescription, axis: .vertical)
                        .lineLimit(3...8)
                }
                Section("Proof (optional)") {
                    if let proofData, let uiImage = UIImage(data: proofData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 180)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    PhotosPicker(selection: $selectedProof, matching: .images) {
                        Label(proofData == nil ? "Add photo" : "Change photo", systemImage: "camera")
                    }
                    if proofData != nil {
                        Button("Remove photo", role: .destructive) {
                            proofData = nil
                            selectedProof = nil
                        }
                    }
                }
                if item != nil {
                    Section {
                        Button("Delete", role: .destructive) { deleteItem() }
                    }
                }
            }
            .navigationTitle(item == nil ? "New Activity" : "Edit Activity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear(perform: populateIfEditing)
            .onChange(of: selectedProof) { _, newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self) {
                        proofData = UIImage(data: data)?.jpegData(compressionQuality: 0.6) ?? data
                    }
                }
            }
        }
    }

    private func populateIfEditing() {
        guard let item else { return }
        title = item.title
        activityDescription = item.activityDescription
        category = item.category ?? ""
        collaborators = item.collaborators ?? ""
        proofData = item.proofData
    }

    private func save() {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedCollaborators = collaborators.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item {
            item.title = title
            item.activityDescription = activityDescription
            item.category = trimmedCategory.isEmpty ? nil : trimmedCategory
            item.collaborators = trimmedCollaborators.isEmpty ? nil : trimmedCollaborators
            item.proofData = proofData
        } else {
            let newItem = Extracurricular(
                title: title,
                activityDescription: activityDescription,
                category: trimmedCategory.isEmpty ? nil : trimmedCategory,
                collaborators: trimmedCollaborators.isEmpty ? nil : trimmedCollaborators,
                proofData: proofData
            )
            modelContext.insert(newItem)
        }
        dismiss()
    }

    private func deleteItem() {
        if let item {
            modelContext.delete(item)
        }
        dismiss()
    }
}

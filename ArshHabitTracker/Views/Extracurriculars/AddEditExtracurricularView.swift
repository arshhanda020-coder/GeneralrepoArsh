//
//  AddEditExtracurricularView.swift
//  ArshHabitTracker
//

import SwiftUI
import SwiftData

struct AddEditExtracurricularView: View {
    let item: Extracurricular?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var activityDescription = ""
    @State private var category = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Activity") {
                    TextField("Title", text: $title)
                    TextField("Category (optional)", text: $category)
                }
                Section("Description") {
                    TextField("What it is, what you do, why it matters", text: $activityDescription, axis: .vertical)
                        .lineLimit(3...8)
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
        }
    }

    private func populateIfEditing() {
        guard let item else { return }
        title = item.title
        activityDescription = item.activityDescription
        category = item.category ?? ""
    }

    private func save() {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        if let item {
            item.title = title
            item.activityDescription = activityDescription
            item.category = trimmedCategory.isEmpty ? nil : trimmedCategory
        } else {
            let newItem = Extracurricular(
                title: title,
                activityDescription: activityDescription,
                category: trimmedCategory.isEmpty ? nil : trimmedCategory
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

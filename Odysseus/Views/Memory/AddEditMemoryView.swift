//
//  AddEditMemoryView.swift
//  Odysseus
//

import SwiftUI
import SwiftData

struct AddEditMemoryView: View {
    let entry: MemoryEntry?

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var content = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Fact") {
                    TextField("What should Odysseus remember?", text: $content, axis: .vertical)
                        .lineLimit(2...6)
                }
                if entry != nil {
                    Section {
                        Button("Delete", role: .destructive) { deleteEntry() }
                    }
                }
            }
            .navigationTitle(entry == nil ? "New Memory" : "Edit Memory")
            .inlineNavigationTitle()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                content = entry?.content ?? ""
            }
            .onSubmit {
                guard !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                save()
            }
        }
    }

    private func save() {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        if let entry {
            entry.content = trimmed
        } else {
            modelContext.insert(MemoryEntry(content: trimmed, isAISaved: false))
        }
        MemoryStore.rebuild(context: modelContext)
        dismiss()
    }

    private func deleteEntry() {
        if let entry {
            modelContext.delete(entry)
        }
        MemoryStore.rebuild(context: modelContext)
        dismiss()
    }
}
